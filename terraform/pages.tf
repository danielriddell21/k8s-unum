# Homepage: a static site on Cloudflare Pages served at the apex (${var.domain}).
#
# Everything else in this repo is a pod behind a Cloudflare Tunnel; the homepage
# is deliberately not. It is four static files with no backend, so putting it on
# Pages keeps it off the 8GB node and out of ArgoCD's reconcile loop entirely.
#
# Content lives in site/ and is uploaded by .github/workflows/pages.yaml
# (wrangler direct upload). Terraform owns the project, the DNS record and the
# custom-domain attachment; it never uploads content. The project must therefore
# exist before the first Pages deploy runs — apply this before pushing site/.
#
# NOTE: var.cloudflare_api_token must additionally have
# "Account > Cloudflare Pages: Edit" for these resources (and for the deploy
# workflow, which reuses the same token).

resource "cloudflare_pages_project" "homepage" {
  account_id        = var.cloudflare_account_id
  name              = "riddellious-dev"
  production_branch = "trunk"
}

# Apex CNAME → the project's pages.dev hostname. Cloudflare's CNAME flattening
# makes a CNAME legal at the zone root; proxied = true is what puts the request
# through the edge, which is also what lets the Access app below gate /admin.
#
# This record is created explicitly (rather than left to Pages' auto-provisioning
# when a custom domain is attached) so the hostname is visible in state next to
# the tunnel records. cloudflare_pages_domain then finds the record already in
# place instead of racing to create its own — hence the depends_on.
resource "cloudflare_record" "homepage_apex" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  content = cloudflare_pages_project.homepage.subdomain
  type    = "CNAME"
  proxied = true
  comment = "apex → Cloudflare Pages homepage"
}

resource "cloudflare_pages_domain" "apex" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.homepage.name
  domain       = var.domain

  depends_on = [cloudflare_record.homepage_apex]
}

# www → apex, 301.
#
# www is deliberately NOT attached to the Pages project as a second custom
# domain: the redirect rule below runs in the dynamic-redirect phase, at the
# edge, before the request is ever routed to an origin, so Pages never sees it.
# The record exists only to make the hostname resolve and be proxied — the
# content it points at is never fetched. (Consequence: delete the rule and www
# starts returning the Pages not-found page rather than the site.)
resource "cloudflare_record" "homepage_www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = cloudflare_pages_project.homepage.subdomain
  type    = "CNAME"
  proxied = true
  comment = "www → 301 to apex (see cloudflare_ruleset.www_redirect)"
}

# One ruleset per zone per phase — if a dynamic-redirect ruleset is ever created
# by hand in the dashboard, this resource will collide with it and has to be
# imported rather than created.
resource "cloudflare_ruleset" "www_redirect" {
  zone_id = var.cloudflare_zone_id
  name    = "www to apex"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    ref         = "www_to_apex"
    description = "301 www.${var.domain} to ${var.domain}"
    expression  = "(http.host eq \"www.${var.domain}\")"
    action      = "redirect"

    action_parameters {
      from_value {
        status_code           = 301
        preserve_query_string = true

        # Path is carried over so a deep link like www.../admin/ still lands in
        # the right place; preserve_query_string handles the rest.
        target_url {
          expression = "concat(\"https://${var.domain}\", http.request.uri.path)"
        }
      }
    }
  }
}
