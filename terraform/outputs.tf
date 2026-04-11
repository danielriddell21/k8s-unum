output "server_ip" {
  description = "Hetzner server public IP"
  value       = hcloud_server.unum.ipv4_address
}

output "tunnel_token" {
  description = "Cloudflare tunnel token — pipe into kubectl create secret after apply"
  value       = cloudflare_zero_trust_tunnel_cloudflared.unum.tunnel_token
  sensitive   = true
}

output "post_apply" {
  description = "Manual steps to complete after terraform apply"
  value       = <<-EOT

    ── After apply ────────────────────────────────────────────────────────────

    1. Wait for k3s (runs via cloud-init, takes ~2 min after server boots):
         ssh root@${hcloud_server.unum.ipv4_address}
         systemctl status k3s

    2. Copy kubeconfig:
         scp root@${hcloud_server.unum.ipv4_address}:/etc/rancher/k3s/k3s.yaml ~/.kube/hetzner-unum.yaml
         sed -i 's/127.0.0.1/${hcloud_server.unum.ipv4_address}/' ~/.kube/hetzner-unum.yaml
         export KUBECONFIG=~/.kube/hetzner-unum.yaml

    3. Create namespace and tunnel secret:
         kubectl create namespace unum
         kubectl create secret generic cloudflared-token \
           --from-literal=token=$(terraform output -raw tunnel_token) \
           -n unum

    4. Install ArgoCD:
         kubectl create namespace argocd
         kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    5. Apply ArgoCD Application (syncs everything else automatically):
         kubectl apply -f ../argocd/application.yaml

    6. Get ArgoCD initial password:
         kubectl -n argocd get secret argocd-initial-admin-secret \
           -o jsonpath="{.data.password}" | base64 -d

    ───────────────────────────────────────────────────────────────────────────
  EOT
}
