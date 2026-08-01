# Secrets

All secrets use [Bitnami Sealed Secrets](https://github.com/bitnami/sealed-secrets). A `SealedSecret` is encrypted with the cluster's public key and safe to commit. The in-cluster controller decrypts it into a real `Secret`.

## Bootstrap (one-time per cluster)

1. Apply the Sealed Secrets controller via ArgoCD:
   ```bash
   KUBECONFIG=~/.kube/hetzner-unum.yaml kubectl apply -f argocd/sealed-secrets.yaml
   ```
   Wait ~1 minute for the controller pod to be ready in `kube-system`.

2. Install `kubeseal` locally:
   ```bash
   go install github.com/bitnami/sealed-secrets/cmd/kubeseal@main
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
riddellious-dev secret manager
==============================
1) cloudflared-unum      unum tunnel token (reads from Terraform state)
2) cloudflared-fiatlux   fiatlux tunnel token (reads from Terraform state)
3) cloudflared-platform  platform tunnel token (reads from Terraform state)
4) postgres              database password (auto-generated, platform ns)
5) umami                 database-url + app-secret (platform ns)
6) otel-collector        auth token (auto-generated, copy to GitHub Actions)
7) grafana               admin password (auto-generated, platform ns)
8) all                   create all secrets in order
9) quit
```

Postgres, Umami, OTel Collector, and Grafana live in the **platform** namespace;
their sealed secrets are bound to that namespace (SealedSecrets are scoped to
`namespace+name`, so a namespace move requires re-sealing). The three cloudflared
tokens are sealed into their respective `unum` / `fiatlux` / `platform` namespaces.

### Notes

- **postgres → umami dependency**: if creating umami standalone, you'll be prompted for the postgres password. If you run `all`, the script reuses the generated postgres password automatically.
- **otel-collector auth-token**: the value printed by the script must also be added as the `OTEL_AUTH_TOKEN` GitHub Actions secret so GoReleaser can bake it into release binaries.
- **Grafana admin password**: printed once — save it or retrieve it later with `kubectl -n platform get secret grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d`.

## Umami website IDs

Website IDs are **not** created by hand. Stable UUIDs are committed in the
ConfigMaps (`manifests/unum/umami-config.yaml` for the four unum tools,
`manifests/fiatlux/fiatlux/configmap.yaml` for kosmos) and seeded into Umami's
Postgres by the `umami-seed` PostSync hook Job
(`manifests/platform/umami/seed-job.yaml`). The Job's INSERT is idempotent, so
it re-runs safely on every sync. If you add a new tracked hostname, add its UUID
to both the relevant ConfigMap and the seed Job's VALUES list.
