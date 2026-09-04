#!/usr/bin/env bash
# ============================================================================
# deploy.sh - End-to-end deployment: Terraform + Kubeconfig + Apps
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
TF_DIR="${ROOT_DIR}/terraform"
K8S_DIR="${ROOT_DIR}/kubernetes"

echo "============================================"
echo "  OKE Free Tier Deployment"
echo "============================================"
echo ""

# --- Phase 1: Terraform ---
echo "=== Phase 1: Infrastructure (Terraform) ==="
cd "$TF_DIR"

terraform init -upgrade
terraform plan -var-file=environments/dev/terraform.tfvars -out=tfplan
terraform apply tfplan
rm -f tfplan

echo ""
echo "Infrastructure deployed."

# --- Phase 2: Kubeconfig ---
echo ""
echo "=== Phase 2: Kubeconfig Setup ==="
"${SCRIPT_DIR}/setup-kubeconfig.sh"

# --- Phase 3: StorageClass ---
echo ""
echo "=== Phase 3: StorageClass ==="
kubectl apply -f "${K8S_DIR}/monitoring/storageclass.yaml"
echo "StorageClass applied."

# --- Phase 4: Cloudflare Tunnel ---
echo ""
echo "=== Phase 4: Cloudflare Tunnel ==="
if [ -f "${K8S_DIR}/cloudflared/secret.yaml" ]; then
  kubectl apply -f "${K8S_DIR}/cloudflared/"
  echo "Cloudflare Tunnel deployed."
else
  echo "SKIPPED: No cloudflared/secret.yaml found."
  echo "  Create it with your tunnel credentials first."
  echo "  See: scripts/setup-cloudflare-tunnel.sh"
fi

# --- Phase 5: ArgoCD ---
echo ""
echo "=== Phase 5: ArgoCD ==="
# Install/upgrade ArgoCD via Helm
if ! helm repo list 2>/dev/null | grep -q "argo"; then
  helm repo add argo https://argoproj.github.io/argo-helm
fi
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values "${K8S_DIR}/argocd/values.yaml" \
  --wait --timeout 10m

echo "ArgoCD deployed."

# Apply ArgoCD Application definitions (Wave 2 apps)
echo ""
echo "Applying ArgoCD Application definitions..."
for app in "${K8S_DIR}/apps"/*/argocd-app.yaml; do
  if [ -f "$app" ]; then
    kubectl apply -f "$app"
    echo "  Applied: $app"
  fi
done

# --- Phase 6: Free Tier Monitor ---
echo ""
echo "=== Phase 6: Free Tier Monitor ==="
kubectl apply -f "${K8S_DIR}/monitoring/"
echo "Free tier monitor deployed."

# --- Summary ---
echo ""
echo "============================================"
echo "  Deployment Complete"
echo "============================================"
echo ""
echo "Cluster:  $(cd "$TF_DIR" && terraform output -raw cluster_name)"
echo "Endpoint: $(cd "$TF_DIR" && terraform output -raw cluster_endpoint)"
echo "K8s:      $(cd "$TF_DIR" && terraform output -raw kubernetes_version)"
echo ""
echo "ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""

DOMAIN=$(cd "$TF_DIR" && terraform output -raw cloudflare_domain 2>/dev/null || echo "")
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "" ]; then
  echo "Services (via Cloudflare Tunnel):"
  echo "  ArgoCD: https://argocd.${DOMAIN}"
  echo "  n8n:    https://n8n.${DOMAIN}"
else
  echo "Cloudflare domain not configured."
  echo "  Set cloudflare_domain in terraform.tfvars"
  echo "  Run scripts/setup-cloudflare-tunnel.sh"
fi

