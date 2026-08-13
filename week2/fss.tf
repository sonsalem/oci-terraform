# ---------------------------------------------------------------------------
# File Storage Service
#
# Three pieces that are easy to confuse:
#   file system  - the NFS filesystem itself, lives in an availability domain
#   mount target - the NFS endpoint, gets a private IP in the private subnet
#   export       - joins the two and publishes a path clients can mount
#
# The application's files live here rather than on the boot volume, so they
# outlive the instance. Destroy and recreate the VM and the content is still
# there.
# ---------------------------------------------------------------------------

resource "oci_file_storage_file_system" "app" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = local.names.file_system
  freeform_tags       = local.common_tags
}

resource "oci_file_storage_mount_target" "app" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  subnet_id           = oci_core_subnet.private.id
  display_name        = local.names.mount_target
  freeform_tags       = local.common_tags
}

resource "oci_file_storage_export" "app" {
  # The mount target creates its own export set; we attach to that rather than
  # managing an oci_file_storage_export_set resource separately.
  export_set_id  = oci_file_storage_mount_target.app.export_set_id
  file_system_id = oci_file_storage_file_system.app.id
  path           = var.fss_export_path

  # Only clients inside the private subnet may mount this. Nothing in the public
  # subnet, and nothing outside the VCN, can reach it.
  export_options {
    source                         = var.private_subnet_cidr
    access                         = var.fss_export_access
    identity_squash                = var.fss_identity_squash
    require_privileged_source_port = var.fss_require_privileged_source_port
  }
}
