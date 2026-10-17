variable "compartment_ocid" {
  description = "Compartment for the backup policy"
  type        = string
}

variable "policy_name" {
  description = "Display name of the backup policy"
  type        = string
}

variable "backup_type" {
  description = "FULL or INCREMENTAL"
  type        = string
}

variable "retention_days" {
  description = "How long each backup is kept. Always Free allows 5 volume backups in total."
  type        = number
}

variable "volume_ids" {
  description = "Volumes to back up, as name => volume OCID (e.g. PVC volumes created by the CSI driver)"
  type        = map(string)
}
