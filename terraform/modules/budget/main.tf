# ============================================================================
# Budget Module - spend alerts for the whole tenancy
# The tenancy is Pay As You Go, so a leaked key could run up a bill. Normal use
# costs nothing, so any spend at all is an alert.
# ============================================================================

# Created by hand in the console, imported into Terraform on 2026-10-21.
resource "oci_budget_budget" "zero_spend" {
  compartment_id = var.tenancy_ocid
  display_name   = "Zero-Spend-Alert"
  amount         = var.amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.tenancy_ocid]
}

# Fires on the first cent actually billed. Billing data lags by hours.
resource "oci_budget_alert_rule" "actual" {
  budget_id      = oci_budget_budget.zero_spend.id
  display_name   = "Penny-Drop-Alert"
  type           = "ACTUAL"
  threshold      = 0.01
  threshold_type = "ABSOLUTE"
  recipients     = var.alert_email
}

# Fires when the month's forecast passes the budget amount, which can come
# before the actual charges show up.
resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.zero_spend.id
  display_name   = "Forecast-Over-Budget"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email
}
