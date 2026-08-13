# Availability domains available to this compartment's region.
data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_id
}

# Sorted newest first, so images[0] is always the latest build matching the OS,
# version and shape. Avoids pinning an image OCID that goes stale.
data "oci_core_images" "app" {
  compartment_id           = var.compartment_id
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# The mount target exposes private IP OCIDs, not addresses. Resolving the first
# one gives cloud-init something it can actually mount, and creates the
# instance -> mount target ordering for free.
data "oci_core_private_ip" "mount_target" {
  private_ip_id = oci_file_storage_mount_target.app.private_ip_ids[0]
}
