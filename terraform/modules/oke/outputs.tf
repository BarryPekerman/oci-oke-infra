output "cluster_id" {
  description = "OKE cluster OCID"
  value       = oci_containerengine_cluster.oke_cluster.id
}

output "cluster_name" {
  description = "OKE cluster name"
  value       = oci_containerengine_cluster.oke_cluster.name
}

output "cluster_kubernetes_version" {
  description = "Kubernetes version running on the cluster"
  value       = oci_containerengine_cluster.oke_cluster.kubernetes_version
}

output "cluster_endpoint" {
  description = "OKE cluster API endpoint"
  value       = oci_containerengine_cluster.oke_cluster.endpoints[0].public_endpoint
}

output "node_pool_id" {
  description = "Node pool OCID"
  value       = oci_containerengine_node_pool.free_tier_pool.id
}

output "k8s_version" {
  description = "Resolved Kubernetes version"
  value       = local.k8s_version
}

