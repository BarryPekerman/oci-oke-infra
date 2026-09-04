output "user_id" {
  description = "OCID of the CI user (upload the API key to this user)"
  value       = oci_identity_domains_user.ci.id
}

output "user_name" {
  description = "Login/user name of the CI identity"
  value       = oci_identity_domains_user.ci.user_name
}

output "group_name" {
  description = "Group granted OKE upgrade permissions"
  value       = oci_identity_domains_group.ci.display_name
}
