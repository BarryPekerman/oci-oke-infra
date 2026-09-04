output "oke_nodes_dynamic_group_id" {
  description = "Dynamic group OCID for OKE worker nodes"
  value       = oci_identity_dynamic_group.oke_nodes.id
}

output "oke_node_policy_id" {
  description = "Policy OCID for OKE node permissions"
  value       = oci_identity_policy.oke_node_policy.id
}

