output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.oke_vcn.id
}

output "public_subnet_id" {
  description = "Public subnet OCID (API endpoint)"
  value       = oci_core_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "Private subnet OCID (worker nodes)"
  value       = oci_core_subnet.private_subnet.id
}

output "api_nsg_id" {
  description = "NSG OCID for OKE API endpoint"
  value       = oci_core_network_security_group.api_nsg.id
}

output "worker_nsg_id" {
  description = "NSG OCID for OKE worker nodes"
  value       = oci_core_network_security_group.worker_nsg.id
}
