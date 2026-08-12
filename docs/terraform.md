# Terraform

Terraform provisions the Hetzner server, three Cloudflare Tunnels (one per namespace: unum, fiatlux, platform) via the `cloudflare_tunnel` module, and the Cloudflare Pages project serving the homepage. State is stored in Cloudflare R2.

## Initial setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# fill in terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply
```

The `unum_tunnel_token`, `fiatlux_tunnel_token`, and `platform_tunnel_token` outputs are sensitive — managed via Sealed Secrets so they can be committed safely. See [secrets.md](secrets.md).

## Homepage (Cloudflare Pages)

`pages.tf` creates the `riddellious-dev` Pages project, the apex `CNAME` pointing
at its `*.pages.dev` hostname, and the custom-domain attachment. `access.tf` adds
a self-hosted Access application on `${domain}/admin` (path-prefix match) so the
admin link page needs a login while the rest of the apex stays public.

Terraform never uploads content — `.github/workflows/pages.yaml` does that with
wrangler. **Apply Terraform before the first Pages deploy**: wrangler will not
create a missing project non-interactively.

Two things to watch on first apply:

- The apex must be free. If the zone already has an `A`, `AAAA` or `CNAME` record
  at the root (a parking page, an old host), the record create fails with
  `81053 — record already exists`; delete it, or `terraform import` it. `MX` and
  `TXT` records at the root are fine — CNAME flattening coexists with them.
- If the custom domain was ever attached by hand in the dashboard, import it
  rather than letting Terraform create a second attachment:
  `terraform import cloudflare_pages_domain.apex <account_id>/riddellious-dev/riddellious.dev`

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

A separate `Pages` workflow (`.github/workflows/pages.yaml`) publishes `site/` on
any push to `trunk` touching it, or manual dispatch. It reuses
`CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` — the token needs
**Account > Cloudflare Pages: Edit** on top of the permissions above.

### GitHub environments

Create two environments under **Settings → Environments**:

- **`terraform-plan`** — no protection rules required
- **`terraform-apply`** — add yourself as a required reviewer

### Required GitHub secrets

| Secret | Description |
|---|---|
| `HETZNER_TOKEN` | Hetzner Cloud API token |
| `SSH_PUBLIC_KEY` | SSH public key (placed on server at provision time) |
| `CLOUDFLARE_API_TOKEN` | Zone:DNS:Edit + Account:Cloudflare Tunnel:Edit + Account:Access: Apps and Policies:Edit + Account:Cloudflare Pages:Edit |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID for the domain |

### Required GitHub variables

Non-sensitive; set as repository **variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Description |
|---|---|
| `ACCESS_EMAIL` | Email allowed through Cloudflare Access (SSO) to Grafana/ArgoCD/Umami |
| `CLOUDFLARE_ACCESS_TEAM_DOMAIN` | Zero Trust team domain, e.g. `myteam.cloudflareaccess.com` |
| `R2_ACCESS_KEY_ID` | R2 API token access key (Terraform state backend) |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret key (Terraform state backend) |
| `OTEL_AUTH_TOKEN` | Bearer token baked into unum release builds and OTel Collector secret |
| `OTEL_ENDPOINT` | Public OTLP endpoint URL (e.g. `https://otel.riddellious.dev`) |
