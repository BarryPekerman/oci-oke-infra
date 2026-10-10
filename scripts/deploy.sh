#!/usr/bin/env bash
# ============================================================================
# deploy.sh - End-to-end deployment: Terraform + Kubeconfig + StorageClass + ArgoCD
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
kubectl apply -f "${K8S_DIR}/storage/storageclass.yaml"
echo "StorageClass applied."

# --- Phase 4: ArgoCD ---
# Apps (wiki, cert-manager, envoy-gateway) are ArgoCD Applications managed from
# the migrate-schitzopunk repo, not from here.
echo ""
echo "=== Phase 4: ArgoCD ==="
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
