module "tunnel_unum" {
  source     = "./modules/cloudflare_tunnel"
  name       = "unum"
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id

  ingress_rules = [
    { hostname = "hash.${var.domain}", service = "http://unum-hash:8080" },
    { hostname = "json.${var.domain}", service = "http://unum-json:8080" },
    { hostname = "diff.${var.domain}", service = "http://unum-diff:8080" },
    { hostname = "diagram.${var.domain}", service = "http://unum-diagram:8080" },
  ]
}

module "tunnel_fiatlux" {
  source     = "./modules/cloudflare_tunnel"
  name       = "fiatlux"
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id

  ingress_rules = [
    { hostname = "kosmos.${var.domain}", service = "http://fiatlux:8080" },
  ]
}

module "tunnel_platform" {
  source     = "./modules/cloudflare_tunnel"
  name       = "platform"
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id

  # Publicly exposed platform services. otel-collector authenticates with a
  # bearer token; Grafana and Umami have their own login. Prometheus, Loki, and
  # Tempo have NO auth and stay cluster-internal (never added here).
  #
  # argocd-server lives in the argocd namespace (reached cross-namespace). It is
  # the cluster control plane — put Cloudflare Access in front of argocd.${domain}
  # and run argocd-server with server.insecure=true (see terraform outputs /
  # docs/operations.md). Routing to :80 (plain HTTP) relies on that insecure mode;
  # TLS is terminated at the Cloudflare edge.
  ingress_rules = [
    { hostname = "otel.${var.domain}", service = "http://otel-collector:4318" },
    { hostname = "grafana.${var.domain}", service = "http://grafana:3000" },
    { hostname = "umami.${var.domain}", service = "http://umami:3000" },
    { hostname = "argocd.${var.domain}", service = "http://argocd-server.argocd:80" },
  ]
}

# Preserve the existing unum tunnel + DNS records under the new module address.
# Without these, terraform would destroy & recreate the tunnel, invalidating
# the sealed cloudflared-token secret already in the cluster.
moved {
  from = random_bytes.tunnel_secret
  to   = module.tunnel_unum.random_bytes.tunnel_secret
}
moved {
  from = cloudflare_zero_trust_tunnel_cloudflared.unum
  to   = module.tunnel_unum.cloudflare_zero_trust_tunnel_cloudflared.this
}
moved {
  from = cloudflare_zero_trust_tunnel_cloudflared_config.unum
  to   = module.tunnel_unum.cloudflare_zero_trust_tunnel_cloudflared_config.this
}
moved {
  from = cloudflare_record.hash
  to   = module.tunnel_unum.cloudflare_record.this["hash"]
}
moved {
  from = cloudflare_record.json
  to   = module.tunnel_unum.cloudflare_record.this["json"]
}
moved {
  from = cloudflare_record.diff
  to   = module.tunnel_unum.cloudflare_record.this["diff"]
}
moved {
  from = cloudflare_record.otel
  to   = module.tunnel_unum.cloudflare_record.this["otel"]
}

# otel-collector moved from the unum namespace to the platform namespace, so the
# otel.${domain} record now lives on the platform tunnel. Move state (content
# updates to the new tunnel id in place) instead of destroy/recreate.
moved {
  from = module.tunnel_unum.cloudflare_record.this["otel"]
  to   = module.tunnel_platform.cloudflare_record.this["otel"]
}
