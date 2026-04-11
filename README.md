# k8s-unum

Kubernetes manifests for [unum](https://github.com/danielriddell21/unum) — deployed on Hetzner Cloud (Nuremberg) via ArgoCD, with public access via Cloudflare Tunnels.

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

Hetzner K8s (Nuremberg) ← ArgoCD watches this repo (root, trunk branch)
```

All three tools run from the same image (`ghcr.io/danielriddell21/unum`) — the K8s Deployment `args` field selects the tool.

---

## Structure

```
k8s-unum/
  manifests/                  # ArgoCD watches this directory (recurse: true)
    namespace.yaml
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
      deployment.yaml         # cloudflared tunnel agent (TUNNEL_TOKEN from secret)
  argocd/
    application.yaml          # ArgoCD Application (applied once manually, not synced)
  terraform/
    main.tf                   # providers + S3 backend
    hetzner.tf                # cx23 server + SSH key (k3s via cloud-init)
    cloudflare.tf             # tunnel + tunnel_config + DNS CNAMEs
    variables.tf
    outputs.tf                # server_ip, tunnel_token (sensitive), post-apply steps
    backend.hcl               # Cloudflare R2 state backend config (fill in ACCOUNT_ID)
    terraform.tfvars.example
  .github/
    actions/
      tf-plan-summary/        # composite action — writes plan to job summary
    workflows/
      terraform.yaml          # validate → plan → apply (apply gated by environment approver)
```

Tunnel ingress routing is managed by Terraform (`cloudflare_zero_trust_tunnel_cloudflared_config`) — cloudflared fetches routing rules from the Cloudflare API using the tunnel token.

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

Three jobs run in sequence on any push to `trunk` touching `terraform/`, any PR, or manual dispatch:

| Job | Environment | Description |
|---|---|---|
| `validate` | — | fmt check, init, validate |
| `plan` | `terraform-plan` | generates plan, publishes summary to job summary, uploads artifact |
| `apply` | `terraform-apply` | downloads plan artifact, applies — **requires approver** |

Apply only runs on `trunk` or manual dispatch. PRs stop after plan.

State is stored in Cloudflare R2 (S3-compatible, free tier).

### GitHub environments

Create two environments under **Settings → Environments**:

- **`terraform-plan`** — no protection rules required
- **`terraform-apply`** — add yourself as a required reviewer

### Required GitHub secrets

| Secret | Description |
|---|---|
| `HETZNER_TOKEN` | Hetzner Cloud API token |
| `SSH_PUBLIC_KEY` | SSH public key (placed on server at provision time) |
| `CLOUDFLARE_API_TOKEN` | Zone:DNS:Edit + Account:Cloudflare Tunnel:Edit |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID for the domain |
| `R2_ACCESS_KEY_ID` | R2 API token access key (Terraform state backend) |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret key (Terraform state backend) |

### R2 state backend setup

1. Cloudflare dashboard → **R2** → **Create bucket** → name it `unum-tfstate`
2. **R2** → **Manage R2 API tokens** → create token with **Object Read & Write** on `unum-tfstate`
3. Edit `terraform/backend.hcl` — replace `ACCOUNT_ID` with your Cloudflare account ID and commit

---

## Provisioning with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# fill in terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply
```

The `tunnel_token` output is sensitive. After apply, create the cluster secret:

```bash
kubectl create namespace unum
kubectl create secret generic cloudflared-token \
  --from-literal=token=$(terraform output -raw tunnel_token) -n unum
```

---

## Local cluster access

Create a `.env` file from `.env.example` with your R2 credentials, then:

```bash
just kubeconfig      # fetches kubeconfig from server via terraform state
just argocd          # port-forwards ArgoCD to https://localhost:9090
just argocd-password # prints ArgoCD admin password
just status          # pod status in unum namespace
just sync-status     # ArgoCD app sync state
```

---

## Updating a deployment

Push to `trunk` in the k8s-unum repo — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
```

To roll back to a specific image tag, edit the `image:` field in the relevant `deployment.yaml` and push.
