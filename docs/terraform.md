# Terraform

Terraform provisions the Hetzner server and the Cloudflare Tunnel (unum namespace) via the `cloudflare_tunnel` module. State is stored in Cloudflare R2.

## Initial setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# fill in terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply
```

The `unum_tunnel_token` output is sensitive — managed via Sealed Secrets so it can be committed safely. See [secrets.md](secrets.md).

## R2 state backend

1. Cloudflare dashboard → **R2** → **Create bucket** → name it `unum-tfstate`
2. **R2** → **Manage R2 API tokens** → create token with **Object Read & Write** on `unum-tfstate`
3. Edit `terraform/backend.hcl` — replace `ACCOUNT_ID` with your Cloudflare account ID and commit

## GitHub Actions workflow

Three jobs run in sequence on any push to `trunk` touching `terraform/`, any PR, or manual dispatch:

| Job | Environment | Description |
|---|---|---|
| `validate` | — | fmt check, init, validate |
| `plan` | `terraform-plan` | generates plan, publishes summary, uploads artifact |
| `apply` | `terraform-apply` | downloads plan artifact, applies — **requires approver** |

Apply only runs on `trunk` or manual dispatch. PRs stop after plan.

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
| `OTEL_AUTH_TOKEN` | Bearer token baked into unum release builds and OTel Collector secret |
| `OTEL_ENDPOINT` | Public OTLP endpoint URL (e.g. `https://otel.riddellious.dev`) |
