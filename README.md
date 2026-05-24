# k8s-unum

Manifests for [unum](https://github.com/danielriddell21/unum), deployed on Hetzner k3s via ArgoCD and fronted by a Cloudflare Tunnel.

## Docs

- [Architecture](docs/architecture.md)
- [Terraform](docs/terraform.md)
- [Secrets](docs/secrets.md)
- [Operations](docs/operations.md)

## Quick start

```bash
just kubeconfig   # fetch kubeconfig
just status       # pod health
just argocd       # https://localhost:9090
just grafana      # http://localhost:3000
```
