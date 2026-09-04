variable "compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR (API endpoint, LB)"
  type        = string
  default     = "10.0.0.0/28"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (worker nodes)"
  type        = string
  default     = "10.0.1.0/24"
}
