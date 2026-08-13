resource "oci_core_instance" "app" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = local.names.instance
  shape               = var.instance_shape
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.private.id
    display_name              = local.names.vnic
    hostname_label            = var.instance_hostname_label
    assign_private_dns_record = true

    # Redundant with prohibit_public_ip_on_vnic on the subnet, but stating it
    # here makes the intent obvious at the instance level too.
    assign_public_ip = false
  }

  source_details {
    source_type             = "image"
    source_id               = local.instance_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  metadata = {
    # file() reads the .pub from disk at apply time and cloud-init installs it
    # for the opc user. Only the public half ever leaves this machine.
    ssh_authorized_keys = file(var.ssh_public_key_path)

    # Mounts the FSS export, seeds the app files onto it, and starts nginx.
    user_data = base64encode(local.cloud_init)
  }

  # cloud-init mounts the export on first boot, so the export has to exist
  # before the instance does. The NAT route has to be in place too, or dnf has
  # no way out to the package repositories.
  depends_on = [
    oci_file_storage_export.app,
    oci_core_route_table.private,
  ]
}
