# ============================================================================
# IAM Module - OKE Free Tier
# Dynamic Groups + Policies for OKE nodes to manage storage, pull images
# ============================================================================

# Dynamic group matching all OKE worker nodes in the compartment
resource "oci_identity_dynamic_group" "oke_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "oke-nodes-${var.environment}"
  description    = "Dynamic group for OKE worker nodes in ${var.environment}"
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

# Policy: Allow OKE nodes to manage block volumes (for PVCs)
resource "oci_identity_policy" "oke_node_policy" {
  compartment_id = var.tenancy_ocid
  name           = "oke-node-policy-${var.environment}"
  description    = "Policies for OKE worker nodes to manage storage and pull images"

  statements = [
    # Block volume management for Kubernetes PVCs
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to manage volumes in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to manage volume-attachments in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to manage volume-backups in compartment id ${var.compartment_ocid}",

    # Allow reading VNICs and subnets for networking
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to use vnics in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to use subnets in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to use network-security-groups in compartment id ${var.compartment_ocid}",

    # Allow reading instance metadata
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to read instances in compartment id ${var.compartment_ocid}",
  ]
}

