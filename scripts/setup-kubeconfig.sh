#!/usr/bin/env bash
# ============================================================================
# setup-kubeconfig.sh - Generate kubeconfig for OKE cluster
# Run after terraform apply to configure kubectl access
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

echo "=== OKE Kubeconfig Setup ==="

# Get cluster info from Terraform outputs
cd "$TF_DIR"

CLUSTER_ID=$(terraform output -raw cluster_id 2>/dev/null) || {
  echo "ERROR: Could not get cluster_id from Terraform. Run 'terraform apply' first."
  exit 1
}

REGION=$(terraform output -raw region 2>/dev/null) || {
  echo "ERROR: Could not get region from Terraform."
  exit 1
}

echo "Cluster ID: $CLUSTER_ID"
echo "Region:     $REGION"

# Create kubeconfig directory
mkdir -p "$HOME/.kube"

# Generate kubeconfig
echo ""
echo "Generating kubeconfig..."
oci ce cluster create-kubeconfig \
  --cluster-id "$CLUSTER_ID" \
  --file "$HOME/.kube/config" \
  --region "$REGION" \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

echo "Kubeconfig written to $HOME/.kube/config"

# Wait for node to be ready
echo ""
echo "Waiting for worker node to be Ready..."
MAX_WAIT=600
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
  if [ "$READY_NODES" -ge 1 ]; then
    echo "Node is Ready!"
    kubectl get nodes -o wide
    break
  fi
  echo "  Waiting for node... ($ELAPSED/${MAX_WAIT}s)"
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
  echo "WARNING: Node not ready after ${MAX_WAIT}s. It may still be provisioning."
  echo "Check: kubectl get nodes"
fi

# Create namespaces
echo ""
echo "Creating namespaces..."
for NS in argocd; do
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
  echo "  Namespace '$NS' ensured"
done

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Cluster endpoint: $(terraform output -raw cluster_endpoint)"
echo ""
echo "Next steps:"
echo "  1. kubectl get nodes       # Verify node is Ready"
echo "  2. kubectl get pods -A     # Check system pods"
echo "  3. ./scripts/deploy.sh     # Deploy apps"

