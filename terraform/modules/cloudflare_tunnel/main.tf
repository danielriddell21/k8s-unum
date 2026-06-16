terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = var.name
  secret     = random_bytes.tunnel_secret.base64
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config {
    dynamic "ingress_rule" {
      for_each = var.ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Key on the subdomain label so moved blocks can reference records by a
# static key (terraform forbids template interpolation in moved-block keys).
resource "cloudflare_record" "this" {
  for_each = { for r in var.ingress_rules : split(".", r.hostname)[0] => r }
  zone_id  = var.zone_id
  name     = each.key
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
}
