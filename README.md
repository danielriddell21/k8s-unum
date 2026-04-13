# k8s-unum

Kubernetes manifests for [unum](https://github.com/danielriddell21/unum) — deployed on Hetzner Cloud (Nuremberg) via ArgoCD, with public access via Cloudflare Tunnels.

```
Internet → Cloudflare DNS + WAF → Cloudflare Tunnel → cloudflared pod → unum pods
                                                                       → otel-collector (bearer auth)
Hetzner k3s (Nuremberg) ← ArgoCD watches manifests/ on trunk
```

## Docs

- [Architecture & structure](docs/architecture.md)
- [Terraform — provisioning, CI, GitHub secrets](docs/terraform.md)
- [Secrets — kubeseal setup and per-service commands](docs/secrets.md)
- [Operations — cluster access, deployments, observability](docs/operations.md)

## Quick start

```bash
just kubeconfig   # fetch kubeconfig from Hetzner server
just status       # check pod health
just argocd       # open ArgoCD at https://localhost:9090
just grafana      # open Grafana at http://localhost:3000
```
