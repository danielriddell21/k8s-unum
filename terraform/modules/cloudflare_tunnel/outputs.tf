output "tunnel_id" {
  description = "Cloudflare tunnel ID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_token" {
  description = "Tunnel token — seal into a kubernetes secret consumed by the cloudflared pod."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.tunnel_token
  sensitive   = true
}
