variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key content for server access"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token — needs Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (found in the right sidebar on any zone's overview page)"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
}

variable "domain" {
  description = "Base domain (e.g. unum.tools)"
  type        = string
  default     = "unum.tools"
}

variable "access_email" {
  description = "Email allowed through Cloudflare Access (one-time PIN) to the platform admin apps (Grafana/ArgoCD/Umami)"
  type        = string
}

variable "cloudflare_access_team_domain" {
  description = "Cloudflare Zero Trust team domain, e.g. myteam.cloudflareaccess.com (Zero Trust dashboard > Settings > Custom Pages). Used to build the OIDC issuer URL for the platform apps."
  type        = string
}
