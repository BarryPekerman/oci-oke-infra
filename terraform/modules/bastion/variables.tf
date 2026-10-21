variable "compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "target_subnet_id" {
  description = "Subnet the bastion's private endpoint lives in (the API NSG must allow 6443 from it)"
  type        = string
}

variable "client_cidr_block_allow_list" {
  description = "Source addresses allowed to connect to the bastion"
  type        = list(string)
}
