# ============================================================================
# Bastion Module - the way in to the private Kubernetes API
# OCI Bastion is a managed service (no VM, no charge). Each session is a
# time-limited SSH port forward to one private IP and port, authorised by OCI
# IAM plus a one-off SSH key, so the allow-list can stay open: GitHub's
# runners (oke-version-guard) need to reach it too.
# ============================================================================

resource "oci_bastion_bastion" "oke" {
  compartment_id               = var.compartment_ocid
  bastion_type                 = "STANDARD"
  name                         = "okebastion${var.environment}"
  target_subnet_id             = var.target_subnet_id
  client_cidr_block_allow_list = var.client_cidr_block_allow_list
  max_session_ttl_in_seconds   = 10800 # the service maximum (3 hours)

  freeform_tags = {
    "managed_by"  = "terraform"
    "environment" = var.environment
  }
}
