# k8s-unum

Kubernetes manifests for [unum](https://github.com/danielriddell21/unum) — deployed on Hetzner Cloud (Frankfurt) via ArgoCD, with public access via Cloudflare Tunnels.

---

## Architecture

```
Internet
  └─→ Cloudflare DNS + WAF (free tier)
        └─→ Cloudflare Tunnel
              └─→ cloudflared pod
                    ├─→ unum-hash  :8080
                    ├─→ unum-json  :8080
                    └─→ unum-diff  :8080

Hetzner K8s (Frankfurt) ← ArgoCD watches this repo (root, main branch)
```

All three tools run from the same image (`ghcr.io/danielriddell21/unum`) — the K8s Deployment `args` field selects the tool.

---

## Structure

```
k8s-unum/
  namespace.yaml              # unum namespace
  hash/
    deployment.yaml
    service.yaml
  json/
    deployment.yaml
    service.yaml
  diff/
    deployment.yaml
    service.yaml
  cloudflared/
    deployment.yaml           # cloudflared tunnel agent (TUNNEL_TOKEN from secret)
  argocd/
    application.yaml          # ArgoCD Application (self-referential)
  terraform/
    main.tf                   # providers + S3 backend
    hetzner.tf                # CX22 server + SSH key (k3s via cloud-init)
    cloudflare.tf             # tunnel + tunnel_config + DNS CNAMEs
    variables.tf
    outputs.tf                # server_ip, tunnel_token (sensitive), post-apply steps
    backend.hcl               # Cloudflare R2 state backend config (fill in ACCOUNT_ID)
    terraform.tfvars.example
  .github/workflows/
    terraform.yaml            # plan on PR, apply on push to main
    bootstrap.yaml            # one-time cluster setup (workflow_dispatch)
```

Tunnel ingress routing is managed by Terraform (`cloudflare_tunnel_config`) — not a local ConfigMap. cloudflared fetches the routing rules from the Cloudflare API using the tunnel token.

---

## Image tags

| Tag | Source |
|---|---|
| `edge` | Latest push to `trunk` in unum repo |
| `sha-<commit>` | Pinned to a specific commit |
| `v<version>` | Tagged release (pre-release by default) |
| `latest` | Release promoted to latest in GitHub UI |

Deployments use `latest` by default. Pin to a specific `sha-` or version tag for stability.

---

## GitHub Actions

### Terraform workflow

Triggers automatically on any push to `main` that touches `terraform/`. On PRs it posts the plan as a comment; on merge it applies.

Can also be triggered manually via **Actions → Terraform → Run workflow** with `plan` or `apply`.

State is stored in Cloudflare R2 (S3-compatible, free tier).

### Bootstrap workflow

One-time setup after the first `terraform apply`. Triggered manually via **Actions → Bootstrap cluster → Run workflow**. It:

1. Reads `server_ip` and `tunnel_token` from Terraform state (via R2)
2. Polls until k3s is active on the server
3. Fetches and patches the kubeconfig
4. Creates the `unum` and `argocd` namespaces
5. Creates the `cloudflared-token` secret
6. Installs ArgoCD and waits for it to be ready
7. Applies `argocd/application.yaml` — ArgoCD takes over from here
8. Prints the ArgoCD initial admin password

### Required GitHub secrets

| Secret | Description |
|---|---|
| `HETZNER_TOKEN` | Hetzner Cloud API token |
| `SSH_PUBLIC_KEY` | SSH public key (added to server at provision time) |
| `SSH_PRIVATE_KEY` | SSH private key (used by bootstrap to SSH into server) |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token — needs Zone:DNS:Edit + Account:Cloudflare Tunnel:Edit |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID for the domain |
| `R2_ACCESS_KEY_ID` | R2 API token access key (for Terraform state) |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret key (for Terraform state) |

Optional GitHub variable: `DOMAIN` (defaults to `unum.tools`).

### R2 state backend setup

1. Cloudflare dashboard → **R2** → **Create bucket** → name it `unum-tfstate`
2. **R2** → **Manage R2 API tokens** → create token with **Object Read & Write** on `unum-tfstate`
3. Edit `terraform/backend.hcl` — replace `ACCOUNT_ID` with your Cloudflare account ID and commit

---

## Provisioning with Terraform

Local usage (after filling in `terraform.tfvars`):

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply
```

The `tunnel_token` output is sensitive — `terraform output -raw tunnel_token` or use the bootstrap workflow.

---

## Initial cluster setup

Run the **Bootstrap cluster** workflow after `terraform apply` completes. It handles everything automatically and prints the ArgoCD password at the end.

Alternatively, do it manually:

```bash
# Export server IP from Terraform output
export SERVER=$(terraform output -raw server_ip)

# Fetch kubeconfig
scp root@$SERVER:/etc/rancher/k3s/k3s.yaml ~/.kube/hetzner-unum.yaml
sed -i "s/127.0.0.1/$SERVER/" ~/.kube/hetzner-unum.yaml
export KUBECONFIG=~/.kube/hetzner-unum.yaml

# Namespaces + secret
kubectl create namespace unum
kubectl create namespace argocd
kubectl create secret generic cloudflared-token \
  --from-literal=token=$(terraform output -raw tunnel_token) -n unum

# ArgoCD
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Hand off to ArgoCD
kubectl apply -f argocd/application.yaml
```

---

## Updating a deployment

Push to `main` — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
```

To roll back to a specific image tag, edit the `image:` field in the relevant `deployment.yaml` and push.
