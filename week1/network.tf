resource "oci_core_vcn" "lab_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = var.vcn_cidr
  display_name   = "${var.lab_name}-vcn"

  # Immutable after creation, so it keeps its original value rather than
  # following var.lab_name. Changing it would force a rebuild of the VCN.
  dns_label = "lab1vcntf"
}

resource "oci_core_internet_gateway" "lab_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "${var.lab_name}-igw"
  enabled        = true
}

# Sends all outbound traffic to the internet gateway. Without this rule the
# gateway exists but nothing routes through it.
resource "oci_core_route_table" "lab_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "${var.lab_name}-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.lab_igw.id
  }
}

# Subnet-level firewall. Protocol numbers are IANA values: 6 is TCP.
resource "oci_core_security_list" "lab_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "${var.lab_name}-security-list"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH open to the internet. Narrow the source to <your.ip>/32 for anything
  # longer-lived than a lab.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"

    tcp_options {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_subnet" "lab_public_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.lab_vcn.id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.lab_name}-public-subnet"
  route_table_id             = oci_core_route_table.lab_route_table.id
  security_list_ids          = [oci_core_security_list.lab_security_list.id]
  prohibit_public_ip_on_vnic = false

  # Immutable after creation, same as the VCN's dns_label above.
  dns_label = "publicsubtf"
}
