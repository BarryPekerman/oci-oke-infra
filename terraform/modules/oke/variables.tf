variable "compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "vcn_id" {
  description = "VCN OCID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet OCID for API endpoint"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet OCID for worker nodes"
  type        = string
}

variable "api_nsg_id" {
  description = "NSG OCID for API endpoint"
  type        = string
}

variable "worker_nsg_id" {
  description = "NSG OCID for worker nodes"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain for node placement"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for node access"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (empty = latest)"
  type        = string
  default     = ""
}

# --- Free tier sizing ---

variable "node_count" {
  description = "Number of worker nodes (1 for free tier)"
  type        = number
  default     = 1
}

variable "node_ocpus" {
  description = "OCPUs per node (4 max free tier for ARM)"
  type        = number
  default     = 4
}

variable "node_memory_gb" {
  description = "Memory in GB per node (24 max free tier for ARM)"
  type        = number
  default     = 24
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB (50 min, counts against 200GB free tier)"
  type        = number
  default     = 50
}

