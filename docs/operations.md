# Operations

## Local cluster access

Create a `.env` file from `.env.example` with your R2 credentials, then use the justfile tasks:

```bash
just kubeconfig       # fetch kubeconfig from server via terraform state
just argocd           # port-forward ArgoCD to https://localhost:9090
just argocd-password  # print ArgoCD admin password
just status           # pod status in unum + fiatlux + platform namespaces
just sync-status      # ArgoCD app sync state
just seal-secrets     # re-seal any token via interactive menu (reads terraform state)
```

## Updating a deployment

Push to `trunk` — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
argocd app sync fiatlux
argocd app sync platform
```

To pin to a specific image tag, edit the `image:` field in the relevant `manifests/<namespace>/<tool>/deployment.yaml` and push.

## Observability & control-plane access

Grafana, Umami, and ArgoCD are exposed publicly and all authenticate through
**Cloudflare Access (OIDC SSO)** — one identity, no per-app passwords. Prometheus,
Loki, and Tempo have no auth and are never exposed — query them through Grafana
datasources. Access is gated to `access_email` (one-time PIN); the Access apps
and policies are managed in `terraform/access.tf`.

| Tool | Login | URL |
|---|---|---|
| Grafana | Cloudflare Access OIDC (auto-login) | https://grafana.riddellious.dev |
| Umami | Cloudflare Access OIDC (via umami-sso) | https://umami.riddellious.dev |
| ArgoCD | Cloudflare Access OIDC | https://argocd.riddellious.dev |

`just argocd` still port-forwards to https://localhost:9090; the Grafana
break-glass admin (`grafana-secret`) works over a port-forward too, bypassing SSO.

> **Security notes**
> - **SSO everywhere:** each app delegates login to Cloudflare Access via OIDC.
>   Grafana uses generic-oauth auto-login; ArgoCD uses `oidc.config`; Umami uses
>   the `umami-sso` sidecar (Umami has no native SSO). Cloudflare verifies identity
>   before issuing tokens, so no app has an internet-facing password prompt.
> - **Umami local password is disabled** by the `umami-seed` Job (set to a
>   non-bcrypt sentinel) so `/api/auth/login` can't bypass SSO.
> - **Grafana** keeps a break-glass admin password in `grafana-secret` for
>   port-forward access only; the public login form is disabled.
> - **ArgoCD** is the cluster control plane; it runs `server.insecure` behind the
>   tunnel (TLS terminated at Cloudflare) and authenticates via OIDC with the
>   `access_email` mapped to `role:admin`.
> - **In-cluster caveat:** SSO protects the public path. Anything already inside
>   the cluster can reach these Services directly; add NetworkPolicies if that
>   matters for your threat model.

## Resizing the VM

Changing `server_type` in `terraform/hetzner.tf` is an in-place resize — the hcloud provider stops the VM, swaps the type, and restarts it (~30s downtime, disk preserved). The disk *capacity* grows but the root partition won't auto-extend; reclaim the extra space on the VM:

```bash
ssh root@<server-ip> "growpart /dev/sda 1 && resize2fs /dev/sda1"
```

