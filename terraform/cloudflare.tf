resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_tunnel" "unum" {
  account_id = var.cloudflare_account_id
  name       = "unum"
  secret     = random_bytes.tunnel_secret.base64
}

resource "cloudflare_tunnel_config" "unum" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.unum.id

  config {
    ingress_rule {
      hostname = "hash.${var.domain}"
      service  = "http://unum-hash:8080"
    }
    ingress_rule {
      hostname = "json.${var.domain}"
      service  = "http://unum-json:8080"
    }
    ingress_rule {
      hostname = "diff.${var.domain}"
      service  = "http://unum-diff:8080"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "hash" {
  zone_id = var.cloudflare_zone_id
  name    = "hash"
  value   = "${cloudflare_tunnel.unum.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "json" {
  zone_id = var.cloudflare_zone_id
  name    = "json"
  value   = "${cloudflare_tunnel.unum.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "diff" {
  zone_id = var.cloudflare_zone_id
  name    = "diff"
  value   = "${cloudflare_tunnel.unum.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
