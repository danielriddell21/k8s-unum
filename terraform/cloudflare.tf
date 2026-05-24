module "tunnel_unum" {
  source     = "./modules/cloudflare_tunnel"
  name       = "unum"
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id

  ingress_rules = [
    { hostname = "hash.${var.domain}", service = "http://unum-hash:8080" },
    { hostname = "json.${var.domain}", service = "http://unum-json:8080" },
    { hostname = "diff.${var.domain}", service = "http://unum-diff:8080" },
    { hostname = "otel.${var.domain}", service = "http://otel-collector:4318" },
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
  to   = module.tunnel_unum.cloudflare_record.this["hash.${var.domain}"]
}
moved {
  from = cloudflare_record.json
  to   = module.tunnel_unum.cloudflare_record.this["json.${var.domain}"]
}
moved {
  from = cloudflare_record.diff
  to   = module.tunnel_unum.cloudflare_record.this["diff.${var.domain}"]
}
moved {
  from = cloudflare_record.otel
  to   = module.tunnel_unum.cloudflare_record.this["otel.${var.domain}"]
}
