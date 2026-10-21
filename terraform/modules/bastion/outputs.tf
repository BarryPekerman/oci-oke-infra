output "bastion_id" {
  description = "Bastion OCID"
  value       = oci_bastion_bastion.oke.id
}
