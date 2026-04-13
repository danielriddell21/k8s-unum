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

## How to create or rotate a secret

```bash
# 1. Create the plain Secret locally — never commit this file
kubectl create secret generic <name> \
  --namespace unum \
  --from-literal=<key>=<value> \
  --dry-run=client -o yaml > /tmp/secret.yaml

# 2. Seal it
kubeseal --format yaml < /tmp/secret.yaml > manifests/<dir>/sealed-secret.yaml

# 3. Remove the plain file
rm /tmp/secret.yaml

# 4. Commit the sealed file
git add manifests/<dir>/sealed-secret.yaml && git commit
```

---

## cloudflared-secret

Used by: `manifests/cloudflared/deployment.yaml`

```bash
just seal-secret   # reads tunnel token from Terraform state, writes sealed-secret.yaml
```

---

## postgres-secret

Used by: `manifests/postgres/statefulset.yaml`

```bash
kubectl create secret generic postgres-secret \
  --namespace unum \
  --from-literal=password=<strong-random-password> \
  --dry-run=client -o yaml > /tmp/secret.yaml
kubeseal --format yaml < /tmp/secret.yaml > manifests/postgres/sealed-secret.yaml
rm /tmp/secret.yaml
```

---

## umami-secret

Used by: `manifests/umami/deployment.yaml`

```bash
kubectl create secret generic umami-secret \
  --namespace unum \
  --from-literal=database-url="postgresql://umami:<postgres-password>@postgres:5432/umami" \
  --from-literal=app-secret=<random-64-char-string> \
  --dry-run=client -o yaml > /tmp/secret.yaml
kubeseal --format yaml < /tmp/secret.yaml > manifests/umami/sealed-secret.yaml
rm /tmp/secret.yaml
```

After Umami is running, log in (`just umami`), create a website, and update `website_id` in `manifests/umami/configmap.yaml`.

---

## otel-collector-secret

Used by: `manifests/otel-collector/deployment.yaml`

The `auth-token` value must match the `OTEL_AUTH_TOKEN` GitHub Actions secret (injected into unum release binaries via GoReleaser ldflags).

```bash
kubectl create secret generic otel-collector-secret \
  --namespace unum \
  --from-literal=auth-token=<strong-random-token> \
  --dry-run=client -o yaml > /tmp/secret.yaml
kubeseal --format yaml < /tmp/secret.yaml > manifests/otel-collector/sealed-secret.yaml
rm /tmp/secret.yaml
```

---

## grafana-secret

Used by: `manifests/grafana/deployment.yaml`

```bash
kubectl create secret generic grafana-secret \
  --namespace unum \
  --from-literal=admin-password=<strong-password> \
  --dry-run=client -o yaml > /tmp/secret.yaml
kubeseal --format yaml < /tmp/secret.yaml > manifests/grafana/sealed-secret.yaml
rm /tmp/secret.yaml
```

Access Grafana: `just grafana` → http://localhost:3000
