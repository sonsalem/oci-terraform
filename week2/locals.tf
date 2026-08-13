locals {
  # Every display name derives from this, so renaming the lab is a one-line change.
  name_prefix = lower(replace(trimspace(var.lab_name), " ", "-"))

  names = {
    vcn                   = "${local.name_prefix}-vcn"
    igw                   = "${local.name_prefix}-igw"
    nat                   = "${local.name_prefix}-nat"
    public_route_table    = "${local.name_prefix}-public-rt"
    private_route_table   = "${local.name_prefix}-private-rt"
    public_security_list  = "${local.name_prefix}-public-sl"
    private_security_list = "${local.name_prefix}-private-sl"
    public_subnet         = "${local.name_prefix}-public-subnet"
    private_subnet        = "${local.name_prefix}-private-subnet"
    instance              = "${local.name_prefix}-app-instance"
    vnic                  = "${local.name_prefix}-app-vnic"
    file_system           = "${local.name_prefix}-fs"
    mount_target          = "${local.name_prefix}-mt"
    load_balancer         = "${local.name_prefix}-lb"
    backend_set           = "${local.name_prefix}-backend-set"
    listener              = "${local.name_prefix}-listener"
  }

  # Named constants beat magic strings scattered through the security rules.
  anywhere_cidr = "0.0.0.0/0"

  # IANA protocol numbers. OCI wants these as strings, "all" is an OCI-ism.
  protocol = {
    all  = "all"
    icmp = "1"
    tcp  = "6"
    udp  = "17"
  }

  # Ports OCI File Storage needs open between an NFS client and its mount target.
  # 111 is rpcbind, 2048-2050 carry NFS, mount and status.
  nfs_tcp_port_ranges = [
    { min = 111, max = 111 },
    { min = 2048, max = 2050 },
  ]

  nfs_udp_port_ranges = [
    { min = 111, max = 111 },
    { min = 2048, max = 2048 },
  ]

  # Empty ssh_allowed_cidrs means "anywhere inside the VCN", derived rather than
  # hardcoded so it follows vcn_cidr automatically.
  ssh_allowed_cidrs = length(var.ssh_allowed_cidrs) > 0 ? var.ssh_allowed_cidrs : [var.vcn_cidr]

  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.availability_domain_index].name

  # Newest image first, so this never pins a stale image OCID.
  instance_image_id = data.oci_core_images.app.images[0].id

  mount_target_ip = data.oci_core_private_ip.mount_target.ip_address

  load_balancer_public_ips = [
    for detail in oci_load_balancer_load_balancer.this.ip_address_details :
    detail.ip_address if detail.is_public
  ]

  # A private load balancer has no public address, so fall back to whichever
  # address it did get rather than failing the output.
  load_balancer_ip = try(
    local.load_balancer_public_ips[0],
    oci_load_balancer_load_balancer.this.ip_address_details[0].ip_address,
  )

  common_tags = merge(
    {
      Lab       = var.lab_name
      Week      = "2"
      ManagedBy = "Terraform"
    },
    var.freeform_tags,
  )

  # Rendered at plan time, handed to cloud-init as base64 user_data.
  cloud_init = templatefile("${path.module}/templates/cloud-init.sh.tftpl", {
    mount_target_ip = local.mount_target_ip
    export_path     = var.fss_export_path
    mount_point     = var.app_mount_point
    app_port        = var.app_port
    app_name        = var.app_name
    lab_name        = var.lab_name
  })
}
