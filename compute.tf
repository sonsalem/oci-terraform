data "oci_identity_availability_domains" "domains" {
  compartment_id = var.compartment_id
}

# Sorted newest first, so images[0] is always the latest Oracle Linux 9 build
# that supports var.vm_shape. Avoids pinning a stale image OCID.
data "oci_core_images" "ol9" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.vm_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "lab_instance" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.domains.availability_domains[0].name
  display_name        = "${var.lab_name}-instance"
  shape               = var.vm_shape

  shape_config {
    ocpus         = var.vm_ocpus
    memory_in_gbs = var.vm_memory_gb
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.lab_public_subnet.id
    assign_public_ip          = true
    display_name              = "${var.lab_name}-vnic"
    assign_private_dns_record = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ol9.images[0].id
  }

  # file() reads the .pub from disk at apply time and cloud-init installs it
  # for the opc user. Only the public half ever leaves this machine.
  metadata = {
    ssh_authorized_keys = file(var.ssh_pubkey_file)
  }
}

resource "oci_core_volume" "lab_block_volume" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.domains.availability_domains[0].name
  display_name        = "${var.lab_name}-block-volume"
  size_in_gbs         = var.volume_size_gb
}

# Paravirtualized shows up as a plain block device, no iSCSI login needed.
# Partitioning, formatting and mounting still happen inside the OS.
resource "oci_core_volume_attachment" "lab_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.lab_instance.id
  volume_id       = oci_core_volume.lab_block_volume.id
}
