output "server_ip" {
  description = "Hetzner server public IP"
  value       = hcloud_server.unum.ipv4_address
}

output "unum_tunnel_token" {
  description = "Cloudflare tunnel token for the unum namespace — seal into manifests/unum/cloudflared/sealed-secret.yaml"
  value       = module.tunnel_unum.tunnel_token
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

    3. Install ArgoCD + Sealed Secrets controller:
         kubectl create namespace argocd
         kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
         kubectl apply -f ../argocd/sealed-secrets.yaml

    4. Seal the cloudflared tunnel token before ArgoCD touches it
       (the committed sealed-secret.yaml file starts as a placeholder; if
       ArgoCD syncs it as-is the SealedSecret controller can't decrypt
       and the cloudflared pod CrashLoops with secret-not-found):
         just seal-secrets   # → option 1 (cloudflared)
         git add manifests/unum/cloudflared/sealed-secret.yaml
         git commit -m "seal: cloudflared token"
         git push

    5. Apply ArgoCD Application (syncs everything automatically):
         kubectl apply -f ../argocd/unum.yaml

    6. Get ArgoCD initial password:
         kubectl -n argocd get secret argocd-initial-admin-secret \
           -o jsonpath="{.data.password}" | base64 -d

    ───────────────────────────────────────────────────────────────────────────
  EOT
}
