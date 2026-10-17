# ============================================================================
# OKE Free Tier Infrastructure
# Maximal Always Free: 1x Basic OKE cluster, 4 OCPU ARM64, 24GB RAM
# ============================================================================

# --- Data Sources ---
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# --- Networking ---
module "networking" {
  source = "./modules/networking"

  compartment_ocid    = var.compartment_ocid
  environment         = var.environment
  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

# --- IAM (Dynamic Groups + Policies) ---
module "iam" {
  source = "./modules/iam"

  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  environment      = var.environment
}

# --- CI upgrader identity (scoped API-key user for oke-version-guard) ---
# IAM-plane only. Opt-in via enable_ci_upgrader; does not touch compute/cluster/storage.
module "ci_upgrader" {
  source = "./modules/ci-upgrader"
  count  = var.enable_ci_upgrader ? 1 : 0

  compartment_ocid = var.compartment_ocid
  environment      = var.environment
  domain_url       = var.ci_domain_url
  user_email       = var.ci_user_email
}

# --- OKE Cluster + Node Pool ---
module "oke" {
  source = "./modules/oke"

  compartment_ocid    = var.compartment_ocid
  environment         = var.environment
  vcn_id              = module.networking.vcn_id
  public_subnet_id    = module.networking.public_subnet_id
  private_subnet_id   = module.networking.private_subnet_id
  api_nsg_id          = module.networking.api_nsg_id
  worker_nsg_id       = module.networking.worker_nsg_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  ssh_public_key      = var.ssh_public_key
  kubernetes_version  = var.kubernetes_version
  node_count          = var.node_count
  node_ocpus          = var.node_ocpus
  node_memory_gb      = var.node_memory_gb
  boot_volume_size_gb = var.boot_volume_size_gb

  depends_on = [module.iam]
}

# --- Volume backups (PVC volumes) ---
module "backups" {
  source = "./modules/backups"

  # Weekly FULL backups kept 10 days: at most 2 exist at a time, plus the one
  # pre-upgrade backup oke-version-guard keeps per volume. Always Free allows 5.
  # FULL (not INCREMENTAL) so each backup stands alone and expires cleanly.
  compartment_ocid = var.compartment_ocid
  policy_name      = "pvc-weekly-${var.environment}"
  backup_type      = "FULL"
  retention_days   = 10
  volume_ids       = var.backup_volume_ids
}
