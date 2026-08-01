# Cloudflare Access for the browser-facing platform admin apps.
#
# Grafana and ArgoCD support OIDC natively, so they use Access SaaS-OIDC apps
# (SSO, no app password). Relying parties discover endpoints at
#   https://<team>.cloudflareaccess.com/cdn-cgi/access/sso/oidc/<client_id>/.well-known/openid-configuration
#
# Umami has no usable OIDC (umami-sso requires an end_session_endpoint that
# Cloudflare Access does not publish), so it uses a self-hosted Access app that
# gates the hostname; Umami keeps its own login behind that gate.
#
# NOTE: var.cloudflare_api_token must additionally have
# "Account > Access: Apps and Policies: Edit" for these resources.

locals {
  # app key => OIDC redirect/callback URL the relying party uses
  access_oidc_apps = {
    grafana = "https://grafana.${var.domain}/login/generic_oauth"
    argocd  = "https://argocd.${var.domain}/auth/callback"
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

# Umami: self-hosted Access app gating the hostname (Umami keeps its own login).
resource "cloudflare_zero_trust_access_application" "umami" {
  account_id       = var.cloudflare_account_id
  name             = "umami"
  domain           = "umami.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "allow_owner_umami" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.umami.id
  name           = "allow-owner-umami"
  precedence     = 1
  decision       = "allow"

  include {
    email = [var.access_email]
  }
}
