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

Grafana and ArgoCD authenticate through **Cloudflare Access (OIDC SSO)** — one
identity, no app password. Umami is exposed with **its own login** (no native
OIDC that works with Access — see below). Prometheus, Loki, and Tempo have no
auth and are never exposed — query them through Grafana datasources. Access is
gated to `access_email` (one-time PIN); the Access apps live in `terraform/access.tf`.

| Tool | Login | URL |
|---|---|---|
| Grafana | Cloudflare Access OIDC (auto-login) | https://grafana.riddellious.dev |
| Umami | Umami's own admin login | https://umami.riddellious.dev |
| ArgoCD | Cloudflare Access OIDC | https://argocd.riddellious.dev |

`just argocd` still port-forwards to https://localhost:9090; the Grafana
break-glass admin (`grafana-secret`) works over a port-forward too, bypassing SSO.

> **Security notes**
> - **Grafana / ArgoCD** delegate login to Cloudflare Access via OIDC (Grafana
>   generic-oauth auto-login; ArgoCD `oidc.config`), so no internet-facing
>   password prompt. Grafana keeps a break-glass admin in `grafana-secret` for
>   port-forward only. ArgoCD is the control plane; it runs `server.insecure`
>   behind the tunnel with `access_email` mapped to `role:admin`.
> - **Umami** has no usable SSO for Cloudflare Access (umami-sso requires an
>   `end_session_endpoint` Cloudflare doesn't publish), so it's exposed with only
>   its own login. It ships with the default `admin`/`umami` — **change the
>   password in the Umami UI after first login**; it is not managed by the seed
>   Job. This is the one public login page, so don't leave it on the default.
> - **In-cluster caveat:** these protections cover the public path. Anything
>   already inside the cluster can reach the Services directly; add NetworkPolicies
>   if that matters for your threat model.

## Resizing the VM

Changing `server_type` in `terraform/hetzner.tf` is an in-place resize — the hcloud provider stops the VM, swaps the type, and restarts it (~30s downtime, disk preserved). The disk *capacity* grows but the root partition won't auto-extend; reclaim the extra space on the VM:

```bash
ssh root@<server-ip> "growpart /dev/sda 1 && resize2fs /dev/sda1"
```

