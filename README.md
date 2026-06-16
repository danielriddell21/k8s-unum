# riddellious-dev

Manifests for [unum](https://github.com/danielriddell21/unum) and the [fiat-lux](https://github.com/danielriddell21/fiat-lux) simulator, deployed on Hetzner k3s via ArgoCD and fronted by a Cloudflare Tunnel.

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
