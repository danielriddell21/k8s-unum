# Secrets

All secrets use [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). A `SealedSecret` is encrypted with the cluster's public key and safe to commit. The in-cluster controller decrypts it into a real `Secret`.

## Bootstrap (one-time per cluster)

1. Apply the Sealed Secrets controller via ArgoCD:
   ```bash
   KUBECONFIG=~/.kube/hetzner-unum.yaml kubectl apply -f argocd/sealed-secrets.yaml
   ```
   Wait ~1 minute for the controller pod to be ready in `kube-system`.

2. Install `kubeseal` locally:
   ```bash
   go install github.com/bitnami-labs/sealed-secrets/cmd/kubeseal@main
   ```

3. Fetch the kubeconfig:
   ```bash
   just kubeconfig
   ```

## Creating or rotating secrets

```bash
just seal-secrets
```

Interactive menu — select which secret to create or rotate. Passwords and tokens are auto-generated. The script writes the sealed YAML to `manifests/<namespace>/<service>/sealed-secret.yaml` — commit and push to deploy.

```
k8s-unum secret manager
========================
1) cloudflared-unum     unum tunnel token (reads from Terraform state)
2) cloudflared-fiatlux  fiatlux tunnel token (reads from Terraform state)
3) postgres             database password (auto-generated)
4) umami                database-url + app-secret
5) otel-collector       auth token (auto-generated, copy to GitHub Actions)
6) grafana              admin password (auto-generated)
7) all                  create all secrets in order
8) quit
```

### Notes

- **postgres → umami dependency**: if creating umami standalone, you'll be prompted for the postgres password. If you run `all`, the script reuses the generated postgres password automatically.
- **otel-collector auth-token**: the value printed by the script must also be added as the `OTEL_AUTH_TOKEN` GitHub Actions secret so GoReleaser can bake it into release binaries.
- **Grafana admin password**: printed once — save it or retrieve it later with `kubectl -n unum get secret grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d`.

## After Umami is running

Log in via `just umami` → http://localhost:3001, create a website, copy the UUID, and update `manifests/unum/umami/configmap.yaml`:

```yaml
data:
  website_id: "<paste-uuid-here>"
```

Commit and push.
