set dotenv-load := true

kubeconfig_path := "~/.kube/hetzner-unum.yaml"

# Fetch kubeconfig from the server via Terraform state (requires .env with R2 credentials)
kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    cd terraform
    terraform init -backend-config=backend.hcl -reconfigure > /dev/null
    SERVER=$(terraform output -raw server_ip)
    cd ..
    mkdir -p ~/.kube
    scp -i ~/.ssh/unum root@"$SERVER":/etc/rancher/k3s/k3s.yaml {{ kubeconfig_path }}
    sed -i "s/127\.0\.0\.1/$SERVER/g" {{ kubeconfig_path }}
    chmod 600 {{ kubeconfig_path }}
    echo "kubeconfig written to {{ kubeconfig_path }}"

# Port-forward ArgoCD to https://localhost:9090
argocd:
    KUBECONFIG={{ kubeconfig_path }} kubectl port-forward svc/argocd-server -n argocd 9090:443

# Print ArgoCD admin password
argocd-password:
    KUBECONFIG={{ kubeconfig_path }} kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d && echo

# Show status of pods in unum and fiatlux namespaces
status:
    KUBECONFIG={{ kubeconfig_path }} kubectl get pods -n unum
    KUBECONFIG={{ kubeconfig_path }} kubectl get pods -n fiatlux

# Show ArgoCD app sync status
sync-status:
    KUBECONFIG={{ kubeconfig_path }} kubectl get applications -n argocd

# Port-forward Grafana to http://localhost:3000 (admin credentials in grafana-secret)
grafana:
    KUBECONFIG={{ kubeconfig_path }} kubectl port-forward svc/grafana -n unum 3000:3000

# Port-forward Umami admin to http://localhost:3001
umami:
    KUBECONFIG={{ kubeconfig_path }} kubectl port-forward svc/umami -n unum 3001:3000

# Create or rotate any sealed secret — interactive menu (requires kubeseal + cluster access)
seal-secrets:
    bash scripts/seal-secrets.sh
