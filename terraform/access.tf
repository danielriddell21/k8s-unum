# Cloudflare Access as the OIDC identity provider for Grafana and ArgoCD, which
# support OIDC natively (SSO, no app password). Relying parties discover
# endpoints at
#   https://<team>.cloudflareaccess.com/cdn-cgi/access/sso/oidc/<client_id>/.well-known/openid-configuration
#
# Umami is NOT behind Access — it has no usable OIDC (umami-sso needs an
# end_session_endpoint Cloudflare doesn't publish), and gating it while keeping
# its own login means two prompts. So Umami is exposed with its own login only
# (strong generated admin password in umami-secret).
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

# The homepage's /admin page (Cloudflare Pages — see pages.tf). Unlike the two
# apps above this is a plain self-hosted app, not OIDC: there is no relying party
# to hand an identity to, just a static page that should not be public. Access
# matches on path prefix, so this covers /admin and everything under it while the
# rest of the apex stays open.
#
# This gates the *page listing* the admin links. Grafana/ArgoCD/Umami each still
# authenticate on their own hostname — removing this app would expose the list,
# not the services.
resource "cloudflare_zero_trust_access_application" "admin" {
  account_id       = var.cloudflare_account_id
  name             = "homepage-admin"
  type             = "self_hosted"
  domain           = "${var.domain}/admin"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "allow_owner_admin" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.admin.id
  name           = "allow-owner-admin"
  precedence     = 1
  decision       = "allow"

  include {
    email = [var.access_email]
  }
}
