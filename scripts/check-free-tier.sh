#!/usr/bin/env bash
# ============================================================================
# check-free-tier.sh - Check OCI resource usage against Always Free limits
# ============================================================================
set -euo pipefail

REGION="${OCI_CLI_REGION:-il-jerusalem-1}"
COMPARTMENT_ID="${OCI_COMPARTMENT_ID:-}"

# Try to get compartment from Terraform if not set
if [ -z "$COMPARTMENT_ID" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TF_DIR="${SCRIPT_DIR}/../terraform"
  if [ -f "${TF_DIR}/terraform.tfstate" ]; then
    cd "$TF_DIR"
    COMPARTMENT_ID=$(terraform output -raw compartment_ocid 2>/dev/null || echo "")
  fi
fi

if [ -z "$COMPARTMENT_ID" ]; then
  echo "ERROR: Set OCI_COMPARTMENT_ID or ensure Terraform state exists"
  exit 1
fi

echo "============================================"
echo "  OCI Always Free Tier Usage Report"
echo "  Region: $REGION"
echo "============================================"
echo ""

# --- Compute ---
echo "=== Compute (Limit: 4 OCPU, 24GB RAM) ==="
INSTANCES=$(oci compute instance list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --lifecycle-state RUNNING \
  --query "data[*].{name:\"display-name\", shape:shape, ocpus:\"shape-config\".ocpus, memory:\"shape-config\".\"memory-in-gbs\"}" \
  --output table 2>/dev/null || echo "  No running instances")
echo "$INSTANCES"

TOTAL_OCPUS=$(oci compute instance list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --lifecycle-state RUNNING \
  --query "data[*].\"shape-config\".ocpus" \
  --output json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(float(x) for x in d if x))" 2>/dev/null || echo "0")
echo ""
echo "  Total OCPUs: ${TOTAL_OCPUS}/4 ($(python3 -c "print(f'{float(${TOTAL_OCPUS})/4*100:.0f}%')"))"

# --- Block Volumes ---
echo ""
echo "=== Block Storage (Limit: 200GB total) ==="
VOLUMES=$(oci bv volume list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --lifecycle-state AVAILABLE \
  --query "data[*].{name:\"display-name\", size_gb:\"size-in-gbs\"}" \
  --output table 2>/dev/null || echo "  No block volumes")
echo "$VOLUMES"

BOOT_VOLUMES=$(oci bv boot-volume list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --availability-domain "$(oci iam availability-domain list -c "$COMPARTMENT_ID" --query "data[0].name" --raw-output 2>/dev/null)" \
  --lifecycle-state AVAILABLE \
  --query "data[*].{name:\"display-name\", size_gb:\"size-in-gbs\"}" \
  --output table 2>/dev/null || echo "  No boot volumes")
echo "Boot Volumes:"
echo "$BOOT_VOLUMES"

TOTAL_BV=$(oci bv volume list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --lifecycle-state AVAILABLE \
  --query "data[*].\"size-in-gbs\"" \
  --output json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(int(x) for x in d if x))" 2>/dev/null || echo "0")
TOTAL_BOOT=$(oci bv boot-volume list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --availability-domain "$(oci iam availability-domain list -c "$COMPARTMENT_ID" --query "data[0].name" --raw-output 2>/dev/null)" \
  --lifecycle-state AVAILABLE \
  --query "data[*].\"size-in-gbs\"" \
  --output json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(int(x) for x in d if x))" 2>/dev/null || echo "0")

TOTAL_STORAGE=$((TOTAL_BV + TOTAL_BOOT))
echo ""
echo "  Block Volumes: ${TOTAL_BV}GB"
echo "  Boot Volumes:  ${TOTAL_BOOT}GB"
echo "  Total Storage: ${TOTAL_STORAGE}/200 GB ($(python3 -c "print(f'{${TOTAL_STORAGE}/200*100:.0f}%')"))"

# --- OKE ---
echo ""
echo "=== OKE Clusters (Limit: 1 Basic cluster) ==="
oci ce cluster list \
  -c "$COMPARTMENT_ID" \
  --region "$REGION" \
  --lifecycle-state ACTIVE \
  --query "data[*].{name:name, type:type, k8s:\"kubernetes-version\"}" \
  --output table 2>/dev/null || echo "  No OKE clusters"

# --- Warnings ---
echo ""
echo "=== Alerts ==="
if [ "$TOTAL_STORAGE" -ge 160 ]; then
  echo "  WARNING: Storage at ${TOTAL_STORAGE}/200 GB (>80%)"
elif [ "$TOTAL_STORAGE" -ge 180 ]; then
  echo "  CRITICAL: Storage at ${TOTAL_STORAGE}/200 GB (>90%)"
else
  echo "  OK: Storage usage is within safe limits"
fi

OCPU_INT=$(python3 -c "print(int(float(${TOTAL_OCPUS})))" 2>/dev/null || echo "0")
if [ "$OCPU_INT" -gt 4 ]; then
  echo "  CRITICAL: Using ${TOTAL_OCPUS} OCPUs (limit: 4)"
elif [ "$OCPU_INT" -ge 4 ]; then
  echo "  INFO: Using all 4 free tier OCPUs"
else
  echo "  OK: Compute usage is within free tier"
fi

echo ""
echo "============================================"

