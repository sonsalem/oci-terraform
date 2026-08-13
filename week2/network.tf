# ---------------------------------------------------------------------------
# VCN
# ---------------------------------------------------------------------------

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = local.names.vcn
  dns_label      = var.vcn_dns_label
  freeform_tags  = local.common_tags
}

# ---------------------------------------------------------------------------
# Gateways
#
# The public subnet reaches the internet both ways through the internet gateway.
# The private subnet gets outbound-only access through the NAT gateway, which is
# what lets the instance install nginx and nfs-utils without ever being
# reachable from the internet.
# ---------------------------------------------------------------------------

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.names.igw
  enabled        = true
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.names.nat
  freeform_tags  = local.common_tags
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.names.public_route_table
  freeform_tags  = local.common_tags

  route_rules {
    destination       = local.anywhere_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.names.private_route_table
  freeform_tags  = local.common_tags

  route_rules {
    destination       = local.anywhere_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }
}

# ---------------------------------------------------------------------------
# Security lists
#
# Subnet-level, stateful firewalls. Rules are generated from variables and
# locals with dynamic blocks so there are no port numbers or CIDRs typed inline.
# ---------------------------------------------------------------------------

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.names.public_security_list
  freeform_tags  = local.common_tags

  egress_security_rules {
    destination = local.anywhere_cidr
    protocol    = local.protocol.all
  }

  # Client traffic arriving at the load balancer listener.
  dynamic "ingress_security_rules" {
    for_each = var.lb_allowed_cidrs

    content {
      source      = ingress_security_rules.value
      protocol    = local.protocol.tcp
      description = "Client traffic to the load balancer listener"

      tcp_options {
        min = var.lb_listener_port
        max = var.lb_listener_port
      }
    }
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.names.private_security_list
  freeform_tags  = local.common_tags

  # Outbound to anywhere, routed through the NAT gateway. Needed for dnf.
  egress_security_rules {
    destination = local.anywhere_cidr
    protocol    = local.protocol.all
  }

  # The load balancer forwards to the app port, sourced from the public subnet.
  ingress_security_rules {
    source      = var.public_subnet_cidr
    protocol    = local.protocol.tcp
    description = "Load balancer to application port"

    tcp_options {
      min = var.app_port
      max = var.app_port
    }
  }

  # NFS between the instance and the mount target. Both live in this subnet, and
  # security lists apply to intra-subnet traffic too, so these rules are required.
  dynamic "ingress_security_rules" {
    for_each = local.nfs_tcp_port_ranges

    content {
      source      = var.private_subnet_cidr
      protocol    = local.protocol.tcp
      description = "NFS/TCP to the File Storage mount target"

      tcp_options {
        min = ingress_security_rules.value.min
        max = ingress_security_rules.value.max
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = local.nfs_udp_port_ranges

    content {
      source      = var.private_subnet_cidr
      protocol    = local.protocol.udp
      description = "NFS/UDP to the File Storage mount target"

      udp_options {
        min = ingress_security_rules.value.min
        max = ingress_security_rules.value.max
      }
    }
  }

  # SSH from inside the VCN only. The instance has no public IP, so reaching it
  # means going through a bastion or Cloud Shell first.
  dynamic "ingress_security_rules" {
    for_each = local.ssh_allowed_cidrs

    content {
      source      = ingress_security_rules.value
      protocol    = local.protocol.tcp
      description = "SSH from inside the VCN"

      tcp_options {
        min = var.ssh_port
        max = var.ssh_port
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = local.names.public_subnet
  dns_label                  = var.public_subnet_dns_label
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.private_subnet_cidr
  display_name   = local.names.private_subnet
  dns_label      = var.private_subnet_dns_label
  route_table_id = oci_core_route_table.private.id

  security_list_ids = [oci_core_security_list.private.id]

  # This is what makes the subnet private: OCI refuses to attach a public IP to
  # any VNIC created here, so the instance simply cannot be exposed by accident.
  prohibit_public_ip_on_vnic = true

  freeform_tags = local.common_tags
}
