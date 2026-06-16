# Architecture

## Traffic flow

```
Internet
  └─→ Cloudflare DNS + WAF (free tier)
        ├─→ Cloudflare Tunnel: unum
        │     └─→ cloudflared pod (unum namespace)
        │           ├─→ unum-hash     :8080
        │           ├─→ unum-json     :8080
        │           ├─→ unum-diff     :8080
        │           └─→ otel-collector :4318  (bearer token auth)
        └─→ Cloudflare Tunnel: fiatlux
              └─→ cloudflared pod (fiatlux namespace)
                    └─→ fiatlux-svc :80

Hetzner K8s (Nuremberg) ← ArgoCD watches manifests/{unum,fiatlux}/ on trunk
```

Each namespace runs its own `cloudflared` pod connected to its own Cloudflare tunnel; the two tunnels share one VM and are provisioned by the same `cloudflare_tunnel` Terraform module. The three unum tools (`hash`/`json`/`diff`) run from the same image (`ghcr.io/danielriddell21/unum`) — the Deployment `args` field selects the tool.

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
    fiatlux/                  # watched by argocd/fiatlux.yaml
      namespace.yaml
      cloudflared/            # fiatlux tunnel client
      fiatlux/                # simulator pod: fiatlux + ollama sidecar (pulls gemma4 via initContainer) + PVC + ConfigMap
      sqld/                   # libSQL primary; strategy: Recreate (single-writer)
  argocd/                     # Applied once manually during cluster bootstrap;
    unum.yaml                 #   ArgoCD lives in its own argocd namespace and
    fiatlux.yaml              #   reconciles workloads into unum + fiatlux.
    sealed-secrets.yaml       # Sealed Secrets controller (kube-system)
  terraform/
    main.tf                   # providers + S3 backend
    hetzner.tf                # cx32 server + SSH key (k3s via cloud-init)
    cloudflare.tf             # two module calls (unum + fiatlux) + moved blocks
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
| `trunk` | Moving tag tracking the upstream `trunk` branch — used by fiat-lux (no tagged releases yet) with `imagePullPolicy: Always` |

unum deployments use a pinned `v<version>` tag. fiat-lux currently rides `:trunk` until it cuts a versioned release. Edit the `image:` field in the relevant deployment and push to roll forward or back.
