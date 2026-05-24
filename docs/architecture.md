# Architecture

## Traffic flow

```
Internet
  └─→ Cloudflare DNS + WAF (free tier)
        └─→ Cloudflare Tunnel: unum
              └─→ cloudflared pod (unum namespace)
                    ├─→ unum-hash     :8080
                    ├─→ unum-json     :8080
                    ├─→ unum-diff     :8080
                    └─→ otel-collector :4318  (bearer token auth)

Hetzner K8s (Nuremberg) ← ArgoCD watches manifests/unum/ on trunk
```

All three tools run from the same image (`ghcr.io/danielriddell21/unum`). The Deployment `args` field selects the tool. Tunnel ingress routing is managed by the `cloudflare_tunnel` Terraform module — cloudflared fetches routing rules from the Cloudflare API using the tunnel token.

## Telemetry stack (cluster-internal only)

```
unum pods (json/diff/hash)
  ├── /metrics          → Prometheus scrapes
  └── OTLP push         → otel-collector:4319 (no auth, in-cluster)

CLI/TUI users (Homebrew installs etc.)
  └── OTLP push         → otel.riddellious.dev → otel-collector:4318 (bearer auth)

otel-collector
  ├── traces            → Loki  (structured event log streams)
  └── metrics :8889     → Prometheus scrapes

Grafana ← Prometheus + Loki   (kubectl port-forward only)
Umami   ← JS snippet via /umami/* proxy on unum pods
```

Grafana, Umami, Prometheus, and Loki are never exposed publicly.

## Repository structure

```
k8s-unum/
  manifests/                  # one subdirectory per namespace
    unum/                     # watched by argocd/unum.yaml
      namespace.yaml
      configmap.yaml
      cloudflared/            # unum tunnel client
      hash/ json/ diff/       # unum tools (Deployment + Service per dir)
      postgres/               # statefulset + service + sealed-secret
      umami/ otel-collector/ grafana/  # deployment + service + configmap + sealed-secret
      prometheus/ loki/ tempo/         # statefulset + service + configmap
  argocd/                     # Applied once manually during cluster bootstrap;
    unum.yaml                 #   ArgoCD lives in its own argocd namespace and
                              #   reconciles workloads into unum.
    sealed-secrets.yaml       # Sealed Secrets controller (kube-system)
  terraform/
    main.tf                   # providers + S3 backend
    hetzner.tf                # cx23 server + SSH key (k3s via cloud-init)
    cloudflare.tf             # one module call (unum) + moved blocks
    modules/cloudflare_tunnel/   # reusable: tunnel + config + per-hostname CNAME
    variables.tf
    outputs.tf
    backend.hcl               # Cloudflare R2 state backend (fill in ACCOUNT_ID)
    terraform.tfvars.example
  docs/
    architecture.md           # this file
    terraform.md
    secrets.md
    operations.md
  .github/
    actions/
      tf-plan-summary/        # composite action — writes plan to job summary
    workflows/
      terraform.yaml          # validate → plan → apply
```

## Image tags

| Tag | Source |
|---|---|
| `edge` | Latest push to `trunk` in unum repo |
| `sha-<commit>` | Pinned to a specific commit |
| `v<version>` | Tagged release |
| `latest` | Release promoted to latest in GitHub UI |

Deployments use a pinned `v<version>` tag. Edit the `image:` field in the relevant deployment and push to roll forward or back.
