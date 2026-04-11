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
  namespace.yaml          # unum namespace
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
    deployment.yaml       # cloudflared tunnel agent (TUNNEL_TOKEN from secret)
  argocd/
    application.yaml      # ArgoCD Application (self-referential)
  terraform/
    main.tf               # provider versions
    hetzner.tf            # CX22 server + SSH key (k3s via cloud-init)
    cloudflare.tf         # tunnel + tunnel_config + DNS CNAMEs
    variables.tf
    outputs.tf            # server_ip, tunnel_token (sensitive), post-apply steps
    terraform.tfvars.example
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

## Provisioning with Terraform

Terraform in `terraform/` provisions the Hetzner server (k3s via cloud-init) and the Cloudflare tunnel + DNS records.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# fill in terraform.tfvars with your tokens
terraform init
terraform apply
# follow the steps printed in the post_apply output
```

The `tunnel_token` output is sensitive — `terraform output -raw tunnel_token` pipes it directly into `kubectl create secret`.

---

## Secrets (not in this repo)

One secret must be created manually (Terraform prints the exact command):

```bash
kubectl create secret generic cloudflared-token \
  --from-literal=token=$(terraform output -raw tunnel_token) \
  -n unum
```

---

## Initial cluster setup

After `terraform apply` and the secret:

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Apply ArgoCD Application — syncs everything else automatically
kubectl apply -f argocd/application.yaml
```

---

## Updating a deployment

Push to `main` — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
```

To roll back to a specific image tag, edit the `image:` field in the relevant `deployment.yaml` and push.
