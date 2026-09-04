# ============================================================================
# OKE Module - Free Tier
# Basic cluster + ARM64 node pool (4 OCPU, 24GB RAM)
# ============================================================================

# --- Lookup latest OKE-compatible Oracle Linux ARM64 image ---
data "oci_containerengine_node_pool_option" "oke_node_pool_options" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

# Get the latest Kubernetes version available
locals {
  # Use latest k8s version or the one specified
  k8s_version = var.kubernetes_version != "" ? var.kubernetes_version : reverse(sort(data.oci_containerengine_node_pool_option.oke_node_pool_options.kubernetes_versions))[0]

  # Find the latest Oracle Linux 8 aarch64 image for OKE
  node_pool_images = [
    for s in data.oci_containerengine_node_pool_option.oke_node_pool_options.sources :
    s if length(regexall("Oracle-Linux-8.*aarch64", s.source_name)) > 0
  ]
  node_image_id = local.node_pool_images[0].image_id
}

# --- OKE Cluster ---
resource "oci_containerengine_cluster" "oke_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.k8s_version
  name               = "oke-free-${var.environment}"
  vcn_id             = var.vcn_id
  type               = "BASIC_CLUSTER"

  # Flannel CNI (default for Basic cluster, no extra subnets needed)
  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  # Public API endpoint so we can reach it without VPN
  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.public_subnet_id
    nsg_ids              = [var.api_nsg_id]
  }

  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }

    # LB subnet (not actively used - Cloudflare Tunnel handles ingress)
    service_lb_subnet_ids = [var.public_subnet_id]

    persistent_volume_config {
      freeform_tags = {
        "managed_by"  = "terraform"
        "free_tier"   = "true"
        "environment" = var.environment
      }
    }
  }

  freeform_tags = {
    "managed_by"  = "terraform"
    "environment" = var.environment
    "free_tier"   = "true"
  }
}

# --- Node Pool (maximal free tier: 4 OCPU, 24GB, 1 node) ---
resource "oci_containerengine_node_pool" "free_tier_pool" {
  cluster_id         = oci_containerengine_cluster.oke_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.k8s_version
  name               = "free-tier-arm64-pool"
  node_shape         = "VM.Standard.A1.Flex"

  # ARM64 shape config: max free tier
  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gb
  }

  node_source_details {
    image_id                = local.node_image_id
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = var.availability_domain
      subnet_id           = var.private_subnet_id
    }

    nsg_ids = [var.worker_nsg_id]

    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
    }

    freeform_tags = {
      "managed_by"  = "terraform"
      "environment" = var.environment
      "free_tier"   = "true"
    }
  }

  ssh_public_key = var.ssh_public_key

  freeform_tags = {
    "managed_by"  = "terraform"
    "environment" = var.environment
    "free_tier"   = "true"
  }
}
