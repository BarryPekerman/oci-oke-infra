# ============================================================================
# OKE Module - Free Tier
# Basic cluster + ARM64 node pool (sized by node_count x node_ocpus/node_memory_gb)
# ============================================================================

# --- Lookup latest OKE-compatible Oracle Linux ARM64 image ---
data "oci_containerengine_node_pool_option" "oke_node_pool_options" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

# Version/image are only used at creation: afterwards oke-version-guard owns them
# (see lifecycle.ignore_changes below).
locals {
  # sort() is lexical (v1.34.10 < v1.34.2), so sort on a zero-padded key instead.
  k8s_versions_sorted = [
    for k in sort([
      for v in data.oci_containerengine_node_pool_option.oke_node_pool_options.kubernetes_versions :
      format("%04d.%04d.%04d|%s",
        tonumber(split(".", trimprefix(v, "v"))[0]),
        tonumber(split(".", trimprefix(v, "v"))[1]),
        tonumber(split(".", trimprefix(v, "v"))[2]),
      v)
    ]) : split("|", k)[1]
  ]
  k8s_version = var.kubernetes_version != "" ? var.kubernetes_version : local.k8s_versions_sorted[length(local.k8s_versions_sorted) - 1]

  # OKE worker images pin a k8s version ("...-OKE-1.35.2-1820"); the image must match
  # k8s_version or OKE rejects the pool. Newest build wins (names embed the build date).
  node_pool_images = sort([
    for s in data.oci_containerengine_node_pool_option.oke_node_pool_options.sources :
    s.source_name if length(regexall("^Oracle-Linux-8\\.[0-9.]+-aarch64-.*-OKE-${replace(trimprefix(local.k8s_version, "v"), ".", "\\.")}-", s.source_name)) > 0
  ])
  node_image_id = length(local.node_pool_images) == 0 ? null : one([
    for s in data.oci_containerengine_node_pool_option.oke_node_pool_options.sources :
    s.image_id if s.source_name == local.node_pool_images[length(local.node_pool_images) - 1]
  ])
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

  # Reach the API through the bastion (scripts/kube-tunnel.sh, and oke-version-guard's
  # bastion-tunnel.sh). The public IP stays on only as the control plane's way out to
  # OCI APIs (CSI volume provisioning, cloud controller): this subnet hosts the wiki's
  # public load balancer, so it routes to the Internet Gateway, and OCI won't add an
  # "All Services" Service Gateway route next to that. Nothing reaches 6443 from the
  # internet: the API NSG has no such rule and the security list doesn't allow it.
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

    # LB subnet: the wiki's public load balancer (Envoy wiki-gateway) lives here. The
    # other sites come in through Cloudflare Tunnels and use no load balancer.
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

  # Version is owned by oke-version-guard after creation; "latest" here would
  # otherwise try to jump minors (OKE refuses) and fight the upgrade automation.
  lifecycle {
    ignore_changes = [kubernetes_version]
  }
}

# --- Node Pool (free tier: node_count x node_ocpus <= 4 OCPU, <= 24GB total) ---
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

  # oke-version-guard upgrades the pool and swaps to the matching OKE worker image.
  lifecycle {
    precondition {
      condition     = local.node_image_id != null
      error_message = "No Oracle Linux 8 aarch64 OKE worker image for Kubernetes ${local.k8s_version}; set kubernetes_version to one that has an image."
    }
    ignore_changes = [kubernetes_version, node_source_details[0].image_id]
  }
}
