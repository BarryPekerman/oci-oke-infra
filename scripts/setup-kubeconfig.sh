#!/usr/bin/env bash
# ============================================================================
# setup-kubeconfig.sh - Wait for the cluster through the bastion tunnel
# The API endpoint is private: start ./scripts/kube-tunnel.sh in another
# terminal first (it writes ~/.kube/oke-private.yaml on its first run).
# Run after terraform apply.
# ============================================================================
set -euo pipefail

export KUBECONFIG="${KUBECONFIG_FILE:-$HOME/.kube/oke-private.yaml}"

echo "=== OKE Kubeconfig Setup ==="
echo "Kubeconfig: $KUBECONFIG (via the bastion tunnel)"

# Wait for the tunnel
MAX_WAIT=600
ELAPSED=0
until [ -f "$KUBECONFIG" ] && kubectl get --raw=/readyz >/dev/null 2>&1; do
  if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "ERROR: API not reachable after ${MAX_WAIT}s. Is ./scripts/kube-tunnel.sh running?"
    exit 1
  fi
  echo "  Waiting for the tunnel (start ./scripts/kube-tunnel.sh in another terminal)... ($ELAPSED/${MAX_WAIT}s)"
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done
echo "API reachable."

# Wait for node to be ready
echo ""
echo "Waiting for worker node to be Ready..."
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
echo "Next steps (with the tunnel running, export KUBECONFIG=$KUBECONFIG):"
echo "  1. kubectl get nodes       # Verify node is Ready"
echo "  2. kubectl get pods -A     # Check system pods"
echo "  3. ./scripts/deploy.sh     # Deploy apps"
