# ============================================================================
# ci-upgrader Module — a dedicated, least-privilege identity for the GitHub
# Actions "oke-version-guard" automation. API-key auth (one scoped key stored
# as a GitHub secret) — simpler than OIDC and fully supported on free tier.
#
# The API key itself is uploaded to this user out-of-band (oci CLI) so the
# private key never lives in Terraform state. This module manages only the
# identity, group membership, and the narrow policy.
# ============================================================================

# --- Dedicated CI user (no email -> no console activation invite) ---
resource "oci_identity_domains_user" "ci" {
  idcs_endpoint = var.domain_url
  schemas       = ["urn:ietf:params:scim:schemas:core:2.0:User"]
  user_name     = "svc-oke-upgrader-${var.environment}"
  description   = "Scoped CI identity for the oke-version-guard automation (API-key auth)"

  name {
    family_name = "Upgrader"
    given_name  = "OKE"
  }

  # IDCS mandates a primary email. This user authenticates via API key, so the
  # one-time activation invite sent here can be ignored.
  emails {
    type    = "work"
    value   = var.user_email
    primary = true
  }

  # IDCS adds its own extension schemas and a "recovery" copy of the email on create;
  # without this every plan wants to strip them.
  lifecycle {
    ignore_changes = [schemas, emails]
  }
}

# --- Group the CI user belongs to; the policy targets this group ---
resource "oci_identity_domains_group" "ci" {
  idcs_endpoint = var.domain_url
  schemas       = ["urn:ietf:params:scim:schemas:core:2.0:Group"]
  display_name  = "oke-upgrader-${var.environment}"

  members {
    type  = "User"
    value = oci_identity_domains_user.ci.id
  }

  # IDCS adds the OCITags extension schema on create, and the provider doesn't read
  # members back (without attribute_sets in state), so every plan would re-add the user.
  lifecycle {
    ignore_changes = [schemas, members]
  }
}

# --- Least-privilege policy: only what an OKE upgrade + node cycle needs ---
resource "oci_identity_policy" "ci" {
  compartment_id = var.compartment_ocid
  name           = "oke-upgrader-policy-${var.environment}"
  description    = "Least-privilege OKE upgrade permissions for the CI identity"

  statements = [
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to manage cluster-family in compartment id ${var.compartment_ocid}",
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to manage instance-family in compartment id ${var.compartment_ocid}",
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to use subnets in compartment id ${var.compartment_ocid}",
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to use vnics in compartment id ${var.compartment_ocid}",
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to use network-security-groups in compartment id ${var.compartment_ocid}",
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to manage volume-backups in compartment id ${var.compartment_ocid}",
    # Creating a backup also needs VOLUME_WRITE on the source volume (pre-upgrade snapshots).
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to use volumes in compartment id ${var.compartment_ocid}",
    # The Kubernetes API is private: CI opens a bastion port-forward session for kubectl.
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to use bastion in compartment id ${var.compartment_ocid}",
    "Allow group '${var.domain_name}'/'${oci_identity_domains_group.ci.display_name}' to manage bastion-session in compartment id ${var.compartment_ocid}",
  ]
}
