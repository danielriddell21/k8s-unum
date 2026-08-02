#!/usr/bin/env bash
# seal-secrets.sh — interactive Sealed Secret manager for riddellious-dev
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

rand_password() { openssl rand -base64 32 | tr -d '\r\n='; }
rand_token()    { openssl rand -hex 32 | tr -d '\r\n'; }

# seal <namespace> <secret-name> <manifests-subdir> [--from-literal=k=v ...]
seal() {
    local namespace="$1" name="$2" dir="$3"
    shift 3
    kubectl create secret generic "$name" \
        --namespace "$namespace" \
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

# tf_output <output-name> — read a value from the terraform state in ../terraform
tf_output() {
    pushd "$REPO_ROOT/terraform" > /dev/null
    terraform init -backend-config=backend.hcl -reconfigure > /dev/null
    terraform output -raw "$1"
    popd > /dev/null
}

seal_cloudflared_unum() {
    echo "→ cloudflared-token (unum)"
    local token
    token=$(tf_output unum_tunnel_token)
    seal unum cloudflared-token unum/cloudflared \
        --from-literal="token=$token"
}

seal_cloudflared_fiatlux() {
    echo "→ cloudflared-token (fiatlux)"
    local token
    token=$(tf_output fiatlux_tunnel_token)
    seal fiatlux cloudflared-token fiatlux/cloudflared \
        --from-literal="token=$token"
}

seal_cloudflared_platform() {
    echo "→ cloudflared-token (platform)"
    local token
    token=$(tf_output platform_tunnel_token)
    seal platform cloudflared-token platform/cloudflared \
        --from-literal="token=$token"
}

seal_postgres() {
    echo "→ postgres-secret"
    POSTGRES_PASSWORD=$(rand_password)
    seal platform postgres-secret platform/postgres \
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
    seal platform umami-secret platform/umami \
        --from-literal="database-url=postgresql://umami:${pg_pass}@postgres:5432/umami" \
        --from-literal="app-secret=$app_secret"
    echo "  (admin login is Umami's default admin/umami — change it in the UI)"
}

seal_otel() {
    echo "→ otel-collector-secret"
    local token
    token=$(rand_token)
    seal platform otel-collector-secret platform/otel-collector \
        --from-literal="auth-token=$token"
    echo "  auth-token: $token"
    echo "  (add this value to GitHub Actions secret: OTEL_AUTH_TOKEN)"
}

seal_grafana() {
    echo "→ grafana-secret (break-glass admin password + Cloudflare Access OIDC)"
    local password issuer
    password=$(rand_password)
    issuer=$(tf_output grafana_oidc_issuer)
    seal platform grafana-secret platform/grafana \
        --from-literal="admin-password=$password" \
        --from-literal="oidc-client-id=$(tf_output grafana_oidc_client_id)" \
        --from-literal="oidc-client-secret=$(tf_output grafana_oidc_client_secret)" \
        --from-literal="oidc-auth-url=${issuer}/authorization" \
        --from-literal="oidc-token-url=${issuer}/token" \
        --from-literal="oidc-api-url=${issuer}/userinfo"
    echo "  admin-password (break-glass, via port-forward): $password"
}

# ── menu ─────────────────────────────────────────────────────────────────────

check_deps

echo ""
echo "riddellious-dev secret manager"
echo "========================"
echo "KUBECONFIG: $KUBECONFIG_PATH"
echo ""

options=(
    "cloudflared-unum      unum tunnel token (reads from Terraform state)"
    "cloudflared-fiatlux   fiatlux tunnel token (reads from Terraform state)"
    "cloudflared-platform  platform tunnel token (reads from Terraform state)"
    "postgres              database password (auto-generated, platform ns)"
    "umami                 database-url + app-secret (platform ns)"
    "otel-collector        auth token (auto-generated, copy to GitHub Actions)"
    "grafana               break-glass admin password + OIDC creds (platform ns)"
    "all                   create all secrets in order"
    "quit"
)

PS3=$'\nSelect secret to create/rotate: '
select opt in "${options[@]}"; do
    case "$REPLY" in
        1) seal_cloudflared_unum ;;
        2) seal_cloudflared_fiatlux ;;
        3) seal_cloudflared_platform ;;
        4) seal_postgres ;;
        5) seal_umami ;;
        6) seal_otel ;;
        7) seal_grafana ;;
        8)
            seal_cloudflared_unum
            seal_cloudflared_fiatlux
            seal_cloudflared_platform
            seal_postgres
            seal_umami
            seal_otel
            seal_grafana
            ;;
        9) echo "bye"; exit 0 ;;
        *) echo "invalid selection — try again"; continue ;;
    esac
    break
done

echo ""
echo "Done. Commit the updated sealed-secret.yaml file(s) and push."
