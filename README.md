# k8s-unum

Kubernetes manifests for [unum](https://github.com/danielriddell21/unum) — deployed on Hetzner Cloud (Frankfurt) via ArgoCD, with public access via Cloudflare Tunnels.

---

## Architecture

```
Internet
  └─→ Cloudflare DNS + WAF (free tier)
        └─→ Cloudflare Tunnel
              └─→ cloudflared pod
                    ├─→ unum-hash  :8080
                    ├─→ unum-json  :8080
                    └─→ unum-diff  :8080

Hetzner K8s (Frankfurt) ← ArgoCD watches this repo (root, main branch)
```

All three tools run from the same image (`ghcr.io/danielriddell21/unum`) — the K8s Deployment `args` field selects the tool.

---

## Structure

```
k8s-unum/
  namespace.yaml          # unum namespace
  hash/
    deployment.yaml
    service.yaml
  json/
    deployment.yaml
    service.yaml
  diff/
    deployment.yaml
    service.yaml
  cloudflared/
    deployment.yaml       # cloudflared tunnel agent
    configmap.yaml        # tunnel ingress routing
  argocd/
    application.yaml      # ArgoCD Application (self-referential)
```

---

## Image tags

| Tag | Source |
|---|---|
| `edge` | Latest push to `trunk` in unum repo |
| `sha-<commit>` | Pinned to a specific commit |
| `v<version>` | Tagged release (pre-release by default) |
| `latest` | Release promoted to latest in GitHub UI |

Deployments use `latest` by default. Pin to a specific `sha-` or version tag for stability.

---

## Secrets (not in this repo)

Two secrets must be created manually in the cluster before ArgoCD syncs:

```bash
# Cloudflare tunnel token — from Zero Trust → Networks → Tunnels
kubectl create secret generic cloudflared-token \
  --from-literal=token=<TUNNEL_TOKEN> \
  -n unum
```

---

## Initial cluster setup

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Apply ArgoCD Application — syncs everything else automatically
kubectl apply -f argocd/application.yaml
```

---

## Updating a deployment

Push to `main` — ArgoCD auto-syncs within ~3 minutes. To force an immediate sync:

```bash
argocd app sync unum
```

To roll back to a specific image tag, edit the `image:` field in the relevant `deployment.yaml` and push.
