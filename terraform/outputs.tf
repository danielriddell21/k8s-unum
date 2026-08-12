output "server_ip" {
  description = "Hetzner server public IP"
  value       = hcloud_server.unum.ipv4_address
}

output "unum_tunnel_token" {
  description = "Cloudflare tunnel token for the unum namespace — seal into manifests/unum/cloudflared/sealed-secret.yaml"
  value       = module.tunnel_unum.tunnel_token
  sensitive   = true
}

output "fiatlux_tunnel_token" {
  description = "Cloudflare tunnel token for the fiatlux namespace — seal into manifests/fiatlux/cloudflared/sealed-secret.yaml"
  value       = module.tunnel_fiatlux.tunnel_token
  sensitive   = true
}

output "platform_tunnel_token" {
  description = "Cloudflare tunnel token for the platform namespace — seal into manifests/platform/cloudflared/sealed-secret.yaml"
  value       = module.tunnel_platform.tunnel_token
  sensitive   = true
}

output "grafana_oidc_client_id" {
  description = "Cloudflare Access OIDC client id for Grafana — seal into grafana-oidc secret"
  value       = cloudflare_zero_trust_access_application.oidc["grafana"].saas_app[0].client_id
  sensitive   = true
}

output "grafana_oidc_client_secret" {
  description = "Cloudflare Access OIDC client secret for Grafana — seal into grafana-oidc secret"
  value       = cloudflare_zero_trust_access_application.oidc["grafana"].saas_app[0].client_secret
  sensitive   = true
}

output "argocd_oidc_client_id" {
  description = "Cloudflare Access OIDC client id for ArgoCD — set in argocd-cm / argocd-secret"
  value       = cloudflare_zero_trust_access_application.oidc["argocd"].saas_app[0].client_id
  sensitive   = true
}

output "argocd_oidc_client_secret" {
  description = "Cloudflare Access OIDC client secret for ArgoCD — set in argocd-secret"
  value       = cloudflare_zero_trust_access_application.oidc["argocd"].saas_app[0].client_secret
  sensitive   = true
}

# Per-app OIDC issuer URLs (team domain + client id). Relying parties derive
# /authorization, /token, /userinfo, /.well-known/openid-configuration from these.
output "grafana_oidc_issuer" {
  description = "OIDC issuer URL for Grafana"
  value       = "https://${var.cloudflare_access_team_domain}/cdn-cgi/access/sso/oidc/${cloudflare_zero_trust_access_application.oidc["grafana"].saas_app[0].client_id}"
  sensitive   = true
}

output "argocd_oidc_issuer" {
  description = "OIDC issuer URL for ArgoCD"
  value       = "https://${var.cloudflare_access_team_domain}/cdn-cgi/access/sso/oidc/${cloudflare_zero_trust_access_application.oidc["argocd"].saas_app[0].client_id}"
  sensitive   = true
}


output "homepage_pages_subdomain" {
  description = "Cloudflare Pages hostname backing the homepage — the apex CNAME target, and the URL to hit when debugging the site with the custom domain bypassed"
  value       = cloudflare_pages_project.homepage.subdomain
}

output "post_apply" {
  description = "Manual steps to complete after terraform apply"
  value       = <<-EOT

    ── After apply ────────────────────────────────────────────────────────────

    1. Wait for k3s (runs via cloud-init, takes ~2 min after server boots):
         ssh root@${hcloud_server.unum.ipv4_address}
         systemctl status k3s

    2. Copy kubeconfig:
         scp root@${hcloud_server.unum.ipv4_address}:/etc/rancher/k3s/k3s.yaml ~/.kube/hetzner-unum.yaml
         sed -i 's/127.0.0.1/${hcloud_server.unum.ipv4_address}/' ~/.kube/hetzner-unum.yaml
         export KUBECONFIG=~/.kube/hetzner-unum.yaml

    3. Install ArgoCD + Sealed Secrets controller (--server-side avoids the
       "metadata.annotations: Too long" error on the applicationsets CRD):
         kubectl create namespace argocd
         kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
         kubectl apply -f ../argocd/sealed-secrets.yaml

    4. Seal all secrets before ArgoCD touches them (the committed
       sealed-secret.yaml files start as placeholders; if ArgoCD syncs them
       as-is the SealedSecret controller can't decrypt and the pods CrashLoop
       with secret-not-found). Sealed secrets are bound to namespace+name, so
       all three cloudflared tokens + the platform secrets must be sealed:
         just seal-secrets   # → option 8 (all): 3 cloudflared tokens +
                             #   postgres/umami/otel/grafana (all platform ns)
         git add manifests/*/cloudflared/sealed-secret.yaml \
                 manifests/platform/*/sealed-secret.yaml
         git commit -m "seal: all secrets"
         git push

    5. Apply ArgoCD Applications (syncs all three namespaces automatically):
         kubectl apply -f ../argocd/unum.yaml
         kubectl apply -f ../argocd/fiatlux.yaml
         kubectl apply -f ../argocd/platform.yaml

    6. Get ArgoCD initial password:
         kubectl -n argocd get secret argocd-initial-admin-secret \
           -o jsonpath="{.data.password}" | base64 -d

    7. Expose ArgoCD at argocd.${var.domain} with Cloudflare Access OIDC SSO.
       argocd-server runs insecure (plain HTTP; TLS terminated at Cloudflare):
         kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge \
           -p '{"data":{"server.insecure":"true"}}'
       Configure OIDC (values from: terraform output -raw argocd_oidc_issuer /
       argocd_oidc_client_id / argocd_oidc_client_secret):
         kubectl -n argocd patch secret argocd-secret --type merge \
           -p '{"stringData":{"oidc.cloudflare.clientSecret":"<argocd_oidc_client_secret>"}}'
         kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{
           "url":"https://argocd.${var.domain}",
           "oidc.config":"name: Cloudflare Access\nissuer: <argocd_oidc_issuer>\nclientID: <argocd_oidc_client_id>\nclientSecret: $oidc.cloudflare.clientSecret\nrequestedScopes: [openid, email, profile]"
         }}'
       Map your identity to admin (RBAC), then restart:
         kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
           -p '{"data":{"policy.default":"","policy.csv":"g, ${var.access_email}, role:admin"}}'
         kubectl -n argocd rollout restart deploy/argocd-server
       Note: argocd CLI (argocd app sync) then needs `argocd login argocd.${var.domain}
       --sso`, or use `just argocd` port-forward for CLI ops.

    ───────────────────────────────────────────────────────────────────────────
  EOT
}
