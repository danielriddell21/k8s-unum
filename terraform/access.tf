# Cloudflare Access as the OIDC identity provider for the browser-facing platform
# admin apps (Grafana, ArgoCD, and Umami via the umami-sso sidecar). Each SaaS
# app issues an OIDC client_id/secret; relying parties discover endpoints at
#   https://<team>.cloudflareaccess.com/cdn-cgi/access/sso/oidc/<client_id>/.well-known/openid-configuration
# Access enforces identity (one-time PIN to var.access_email) before issuing
# tokens, so the apps delegate login entirely to Cloudflare (no app passwords).
#
# NOTE: var.cloudflare_api_token must additionally have
# "Account > Access: Apps and Policies: Edit" for these resources.

locals {
  # app key => OIDC redirect/callback URL the relying party uses
  access_oidc_apps = {
    grafana = "https://grafana.${var.domain}/login/generic_oauth"
    argocd  = "https://argocd.${var.domain}/auth/callback"
    umami   = "https://umami.${var.domain}/login/callback"
  }
}

resource "cloudflare_zero_trust_access_application" "oidc" {
  for_each         = local.access_oidc_apps
  account_id       = var.cloudflare_account_id
  name             = each.key
  type             = "saas"
  session_duration = "24h"

  saas_app {
    auth_type     = "oidc"
    redirect_uris = [each.value]
    grant_types   = ["authorization_code"]
    scopes        = ["openid", "email", "profile"]
  }
}

resource "cloudflare_zero_trust_access_policy" "allow_owner" {
  for_each       = local.access_oidc_apps
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.oidc[each.key].id
  name           = "allow-owner-${each.key}"
  precedence     = 1
  decision       = "allow"

  include {
    email = [var.access_email]
  }
}
