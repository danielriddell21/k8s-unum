# Operations

## Local cluster access

Create a `.env` file from `.env.example` with your R2 credentials, then use the justfile tasks:

```bash
just kubeconfig       # fetch kubeconfig from server via terraform state
just argocd           # port-forward ArgoCD to https://localhost:9090
just argocd-password  # print ArgoCD admin password
just status           # pod status in unum namespace
just sync-status      # ArgoCD app sync state
just seal-secret      # re-seal cloudflared token (reads terraform state, writes sealed-secret.yaml)
just grafana          # port-forward Grafana to http://localhost:3000
just umami            # port-forward Umami admin to http://localhost:3001
```

## Updating a deployment

Push to `trunk` — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
```

To pin to a specific image tag, edit the `image:` field in the relevant `manifests/<tool>/deployment.yaml` and push.

## Observability access

All observability tools are cluster-internal only — never exposed publicly.

| Tool | Command | URL |
|---|---|---|
| Grafana | `just grafana` | http://localhost:3000 |
| Umami admin | `just umami` | http://localhost:3001 |
| ArgoCD | `just argocd` | https://localhost:9090 |

Prometheus and Loki have no UI — query them through Grafana datasources.
