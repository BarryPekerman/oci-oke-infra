# Weekly block-volume backups for PVC volumes.
# The volumes themselves are created by the OKE CSI driver (PersistentVolumeClaims),
# so only the policy and its assignments live here.

resource "oci_core_volume_backup_policy" "weekly" {
  compartment_id = var.compartment_ocid
  display_name   = var.policy_name

  schedules {
    backup_type       = var.backup_type
    period            = "ONE_WEEK"
    day_of_week       = "SUNDAY"
    hour_of_day       = 3
    offset_type       = "STRUCTURED"
    time_zone         = "UTC"
    retention_seconds = var.retention_days * 24 * 3600
  }
}

resource "oci_core_volume_backup_policy_assignment" "volume" {
  for_each = var.volume_ids

  asset_id  = each.value
  policy_id = oci_core_volume_backup_policy.weekly.id
}
