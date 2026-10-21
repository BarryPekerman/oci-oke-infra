variable "tenancy_ocid" {
  description = "OCI Tenancy OCID (the budget covers the whole tenancy)"
  type        = string
}

variable "amount" {
  description = "Monthly budget, in the tenancy's currency (EUR)"
  type        = number
}

variable "alert_email" {
  description = "Where budget alerts are sent"
  type        = string
}
