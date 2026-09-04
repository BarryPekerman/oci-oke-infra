variable "compartment_ocid" {
  description = "OCI Compartment OCID where OKE lives"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "domain_url" {
  description = "Identity domain IDCS endpoint URL, e.g. https://idcs-xxxx.identity.oraclecloud.com"
  type        = string
}

variable "domain_name" {
  description = "Identity domain name used in IAM policy group references"
  type        = string
  default     = "Default"
}

variable "user_email" {
  description = "Primary email for the CI user (IDCS requires one). Use a plus-tagged address to filter the one-time activation invite. API-key auth does not need activation."
  type        = string
}
