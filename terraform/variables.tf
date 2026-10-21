# ============================================================================
# Root Variables - OKE Free Tier Infrastructure
# ============================================================================

# --- OCI Authentication ---

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "il-jerusalem-1"
}

# --- Environment ---

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
  default     = "dev"
}

# --- SSH ---

variable "ssh_public_key" {
  description = "SSH public key for node access (emergency)"
  type        = string
}

# --- OKE Node Sizing (Free Tier Defaults) ---

variable "node_ocpus" {
  description = "OCPUs per worker node (total across all nodes must not exceed 4 for Always Free ARM)"
  type        = number
  default     = 2
}

variable "node_memory_gb" {
  description = "Memory per worker node in GB (total across all nodes must not exceed 24 for Always Free ARM)"
  type        = number
  default     = 12
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB (min 50, counts against 200GB free limit)"
  type        = number
  default     = 50
}

variable "kubernetes_version" {
  description = "Kubernetes version (empty = latest available)"
  type        = string
  default     = ""
}

# --- Networking ---

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR (API endpoint)"
  type        = string
  default     = "10.0.0.0/28"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (worker nodes)"
  type        = string
  default     = "10.0.1.0/24"
}

# --- CI upgrader identity (scoped API-key user for the OKE version-guard) ---

variable "enable_ci_upgrader" {
  description = "Create the scoped CI identity + group + policy for the oke-version-guard automation"
  type        = bool
  default     = false
}

variable "ci_domain_url" {
  description = "Identity domain IDCS endpoint URL, e.g. https://idcs-xxxx.identity.oraclecloud.com"
  type        = string
  default     = ""
}

variable "ci_user_email" {
  description = "Primary email for the CI user (IDCS requires one; use a plus-tagged address)"
  type        = string
  default     = ""
}

# --- Volume backups ---

variable "backup_volume_ids" {
  description = "PVC volumes to back up weekly, as name => volume OCID"
  type        = map(string)
  default     = {}
}

# --- Budget ---

variable "budget_alert_email" {
  description = "Where budget alerts are sent"
  type        = string
}
