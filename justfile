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

# Show status of pods in unum, fiatlux, and platform namespaces
status:
    KUBECONFIG={{ kubeconfig_path }} kubectl get pods -n unum
    KUBECONFIG={{ kubeconfig_path }} kubectl get pods -n fiatlux
    KUBECONFIG={{ kubeconfig_path }} kubectl get pods -n platform

# Show ArgoCD app sync status
sync-status:
    KUBECONFIG={{ kubeconfig_path }} kubectl get applications -n argocd

# Serve the static homepage locally at http://localhost:8000
site:
    python3 -m http.server -d site 8000

# Create or rotate any sealed secret — interactive menu (requires kubeseal + cluster access)
seal-secrets:
    bash scripts/seal-secrets.sh
