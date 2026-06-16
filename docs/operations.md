# Operations

## Local cluster access

Create a `.env` file from `.env.example` with your R2 credentials, then use the justfile tasks:

```bash
just kubeconfig       # fetch kubeconfig from server via terraform state
just argocd           # port-forward ArgoCD to https://localhost:9090
just argocd-password  # print ArgoCD admin password
just status           # pod status in unum + fiatlux namespaces
just sync-status      # ArgoCD app sync state
just seal-secrets     # re-seal any token via interactive menu (reads terraform state)
just grafana          # port-forward Grafana to http://localhost:3000
just umami            # port-forward Umami admin to http://localhost:3001
```

## Updating a deployment

Push to `trunk` — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
argocd app sync fiatlux
```

To pin to a specific image tag, edit the `image:` field in the relevant `manifests/<namespace>/<tool>/deployment.yaml` and push.

## Observability access

All observability tools are cluster-internal only — never exposed publicly.

| Tool | Command | URL |
|---|---|---|
| Grafana | `just grafana` | http://localhost:3000 |
| Umami admin | `just umami` | http://localhost:3001 |
| ArgoCD | `just argocd` | https://localhost:9090 |

Prometheus and Loki have no UI — query them through Grafana datasources.

## Resizing the VM

Changing `server_type` in `terraform/hetzner.tf` is an in-place resize — the hcloud provider stops the VM, swaps the type, and restarts it (~30s downtime, disk preserved). The disk *capacity* grows but the root partition won't auto-extend; reclaim the extra space on the VM:

```bash
ssh root@<server-ip> "growpart /dev/sda 1 && resize2fs /dev/sda1"
```

