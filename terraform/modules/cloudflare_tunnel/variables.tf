variable "name" {
  description = "Tunnel name (also used as the resource label prefix)."
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID for the DNS records."
  type        = string
}

variable "ingress_rules" {
  description = "Ordered list of {hostname, service} ingress rules. A catch-all 404 is appended automatically. One CNAME record is created per hostname."
  type = list(object({
    hostname = string
    service  = string
  }))
}
