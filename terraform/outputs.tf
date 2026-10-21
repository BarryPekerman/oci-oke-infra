# ============================================================================
# Outputs - OKE Free Tier
# ============================================================================

output "cluster_id" {
  description = "OKE cluster OCID"
  value       = module.oke.cluster_id
}

output "cluster_name" {
  description = "OKE cluster name"
  value       = module.oke.cluster_name
}

output "cluster_endpoint" {
  description = "OKE Kubernetes API endpoint"
  value       = module.oke.cluster_endpoint
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster (upgrades are owned by oke-version-guard)"
  value       = module.oke.cluster_kubernetes_version
}

output "cluster_private_endpoint" {
  description = "OKE Kubernetes API private endpoint (ip:port), reached through the bastion"
  value       = module.oke.cluster_private_endpoint
}

output "bastion_id" {
  description = "Bastion OCID (scripts/kube-tunnel.sh opens sessions on it)"
  value       = module.bastion.bastion_id
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}

output "vcn_id" {
  description = "VCN OCID"
  value       = module.networking.vcn_id
}

output "region" {
  description = "OCI region"
  value       = var.region
}

output "environment" {
  description = "Environment"
  value       = var.environment
}

output "compartment_ocid" {
  description = "Compartment OCID"
  value       = var.compartment_ocid
}

# --- Free Tier Budget Info ---
output "free_tier_usage" {
  description = "Estimated free tier usage"
  value = {
    compute_ocpus     = "${var.node_ocpus * var.node_count} / 4 OCPU"
    compute_memory_gb = "${var.node_memory_gb * var.node_count} / 24 GB"
    boot_volume_gb    = "${var.boot_volume_size_gb * var.node_count} / 200 GB (shared with PVCs)"
    remaining_storage = "${200 - (var.boot_volume_size_gb * var.node_count)} GB available for PVCs"
    cluster_type      = "BASIC (Always Free)"
  }
}
