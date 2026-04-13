#!/usr/bin/env bash
# seal-secrets.sh — interactive Sealed Secret manager for k8s-unum
# Run via: just seal-secrets
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/hetzner-unum.yaml}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POSTGRES_PASSWORD=""  # set by seal_postgres, reused by seal_umami in "all" mode

# ── helpers ──────────────────────────────────────────────────────────────────

check_deps() {
    for cmd in kubectl kubeseal openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "error: $cmd not found in PATH" >&2
            exit 1
        fi
    done
}

rand_password() { openssl rand -base64 32 | tr -d '\n='; }
rand_token()    { openssl rand -hex 32; }

# seal <secret-name> <manifests-subdir> [--from-literal=k=v ...]
seal() {
    local name="$1" dir="$2"
    shift 2
    kubectl create secret generic "$name" \
        --namespace unum \
        "$@" \
        --dry-run=client -o yaml | \
        KUBECONFIG="$KUBECONFIG_PATH" kubeseal \
            --controller-namespace=kube-system \
            --controller-name=sealed-secrets \
            --format=yaml \
        > "$REPO_ROOT/manifests/$dir/sealed-secret.yaml"
    echo "  written → manifests/$dir/sealed-secret.yaml"
}

# ── per-secret functions ──────────────────────────────────────────────────────

seal_cloudflared() {
    echo "→ cloudflared-secret"
    pushd "$REPO_ROOT/terraform" > /dev/null
    terraform init -backend-config=backend.hcl -reconfigure > /dev/null
    local token
    token=$(terraform output -raw tunnel_token)
    popd > /dev/null
    seal cloudflared-token cloudflared \
        --from-literal="token=$token"
}

seal_postgres() {
    echo "→ postgres-secret"
    POSTGRES_PASSWORD=$(rand_password)
    seal postgres-secret postgres \
        --from-literal="password=$POSTGRES_PASSWORD"
    echo "  password: $POSTGRES_PASSWORD"
    echo "  (copy this — you will need it when creating umami-secret)"
}

seal_umami() {
    echo "→ umami-secret"
    local pg_pass="$POSTGRES_PASSWORD"
    if [[ -z "$pg_pass" ]]; then
        read -rsp "  postgres password (from postgres-secret): " pg_pass
        echo
    fi
    local app_secret
    app_secret=$(rand_token)
    seal umami-secret umami \
        --from-literal="database-url=postgresql://umami:${pg_pass}@postgres:5432/umami" \
        --from-literal="app-secret=$app_secret"
}

seal_otel() {
    echo "→ otel-collector-secret"
    local token
    token=$(rand_token)
    seal otel-collector-secret otel-collector \
        --from-literal="auth-token=$token"
    echo "  auth-token: $token"
    echo "  (add this value to GitHub Actions secret: OTEL_AUTH_TOKEN)"
}

seal_grafana() {
    echo "→ grafana-secret"
    local password
    password=$(rand_password)
    seal grafana-secret grafana \
        --from-literal="admin-password=$password"
    echo "  admin-password: $password"
}

# ── menu ─────────────────────────────────────────────────────────────────────

check_deps

echo ""
echo "k8s-unum secret manager"
echo "========================"
echo "KUBECONFIG: $KUBECONFIG_PATH"
echo ""

options=(
    "cloudflared      tunnel token (reads from Terraform state)"
    "postgres         database password (auto-generated)"
    "umami            database-url + app-secret"
    "otel-collector   auth token (auto-generated, copy to GitHub Actions)"
    "grafana          admin password (auto-generated)"
    "all              create all secrets in order"
    "quit"
)

PS3=$'\nSelect secret to create/rotate: '
select opt in "${options[@]}"; do
    case "$REPLY" in
        1) seal_cloudflared ;;
        2) seal_postgres ;;
        3) seal_umami ;;
        4) seal_otel ;;
        5) seal_grafana ;;
        6)
            seal_cloudflared
            seal_postgres
            seal_umami
            seal_otel
            seal_grafana
            ;;
        7) echo "bye"; exit 0 ;;
        *) echo "invalid selection — try again"; continue ;;
    esac
    break
done

echo ""
echo "Done. Commit the updated sealed-secret.yaml file(s) and push."
