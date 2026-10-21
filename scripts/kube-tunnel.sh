#!/usr/bin/env bash
# ============================================================================
# kube-tunnel.sh - reach the private Kubernetes API through the OCI Bastion
#
# Opens a bastion port-forward session (throwaway SSH key, 3-hour max) and
# forwards 127.0.0.1:6443 to the API's private endpoint. Runs in the
# foreground; Ctrl-C closes the tunnel and deletes the session.
#
#   ./scripts/kube-tunnel.sh                 # in one terminal
#   export KUBECONFIG=~/.kube/oke-private.yaml && kubectl get nodes   # in another
#
# The kubeconfig is written on first run: the private endpoint, with the
# server rewritten to the tunnel and the TLS name kept as the API's private IP
# (the certificate is issued for it, not for 127.0.0.1).
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"
LOCAL_PORT="${LOCAL_PORT:-6443}"
KUBECONFIG_FILE="${KUBECONFIG_FILE:-$HOME/.kube/oke-private.yaml}"
TTL=10800

tf_out() { (cd "$TF_DIR" && terraform output -raw "$1"); }
BASTION_ID="${BASTION_ID:-$(tf_out bastion_id)}"
ENDPOINT="${ENDPOINT:-$(tf_out cluster_private_endpoint)}"   # ip:port
REGION="${REGION:-$(tf_out region)}"
CLUSTER_ID="${CLUSTER_ID:-$(tf_out cluster_id)}"
API_IP="${ENDPOINT%:*}"
API_PORT="${ENDPOINT##*:}"

# --- Kubeconfig (first run only) ---
if [ ! -f "$KUBECONFIG_FILE" ]; then
  echo "Writing $KUBECONFIG_FILE"
  oci ce cluster create-kubeconfig --cluster-id "$CLUSTER_ID" --region "$REGION" \
    --file "$KUBECONFIG_FILE" --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT >/dev/null
  chmod 600 "$KUBECONFIG_FILE"
  cluster=$(KUBECONFIG="$KUBECONFIG_FILE" kubectl config view -o jsonpath='{.clusters[0].name}')
  KUBECONFIG="$KUBECONFIG_FILE" kubectl config set-cluster "$cluster" \
    --server="https://127.0.0.1:${LOCAL_PORT}" --tls-server-name="$API_IP" >/dev/null
fi

# --- Session ---
KEY_DIR=$(mktemp -d)
SESSION_ID=""
SSH_PID=""
cleanup() {
  [ -n "$SSH_PID" ] && kill "$SSH_PID" 2>/dev/null || true
  if [ -n "$SESSION_ID" ]; then
    echo "Deleting bastion session"
    oci bastion session delete --session-id "$SESSION_ID" --region "$REGION" --force >/dev/null 2>&1 || true
  fi
  rm -rf "$KEY_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

ssh-keygen -q -t ed25519 -N '' -C kube-tunnel -f "$KEY_DIR/key"

echo "Creating bastion session to ${API_IP}:${API_PORT} (up to a minute)"
SESSION_ID=$(oci bastion session create-port-forwarding --region "$REGION" \
  --bastion-id "$BASTION_ID" --display-name "kube-tunnel-$(whoami)" \
  --target-private-ip "$API_IP" --target-port "$API_PORT" \
  --ssh-public-key-file "$KEY_DIR/key.pub" --session-ttl "$TTL" \
  --query 'data.id' --raw-output)

for _ in $(seq 1 60); do
  state=$(oci bastion session get --session-id "$SESSION_ID" --region "$REGION" \
    --query 'data."lifecycle-state"' --raw-output)
  [ "$state" = "ACTIVE" ] && break
  [ "$state" = "FAILED" ] && { echo "ERROR: bastion session FAILED" >&2; exit 1; }
  sleep 3
done
[ "$state" = "ACTIVE" ] || { echo "ERROR: bastion session not ACTIVE after 3 minutes" >&2; exit 1; }

# A freshly ACTIVE session can refuse SSH for a few seconds; retry briefly.
for attempt in 1 2 3 4 5; do
  ssh -i "$KEY_DIR/key" -N -p 22 \
    -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KEY_DIR/known_hosts" \
    -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes \
    -L "127.0.0.1:${LOCAL_PORT}:${API_IP}:${API_PORT}" \
    "${SESSION_ID}@host.bastion.${REGION}.oci.oraclecloud.com" &
  SSH_PID=$!
  sleep 5
  if kill -0 "$SSH_PID" 2>/dev/null; then break; fi
  SSH_PID=""
  echo "  SSH not accepted yet (attempt $attempt), retrying"
  sleep 5
done
[ -n "$SSH_PID" ] || { echo "ERROR: could not open the SSH tunnel" >&2; exit 1; }

echo ""
echo "Tunnel up: 127.0.0.1:${LOCAL_PORT} -> ${API_IP}:${API_PORT} (session ends in $((TTL / 3600))h)"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "Ctrl-C to close."
wait "$SSH_PID"
