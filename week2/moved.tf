# Maps the old lab1_* resource addresses onto the new lab_* ones so the rename
# updates state instead of destroying and recreating live infrastructure.
# Safe to delete once `terraform apply` has run and state is on the new names.

moved {
  from = oci_core_vcn.lab1_vcn
  to   = oci_core_vcn.lab_vcn
}

moved {
  from = oci_core_internet_gateway.lab1_igw
  to   = oci_core_internet_gateway.lab_igw
}

moved {
  from = oci_core_route_table.lab1_route_table
  to   = oci_core_route_table.lab_route_table
}

moved {
  from = oci_core_security_list.lab1_security_list
  to   = oci_core_security_list.lab_security_list
}

moved {
  from = oci_core_subnet.lab1_public_subnet
  to   = oci_core_subnet.lab_public_subnet
}

moved {
  from = oci_core_instance.lab1_instance
  to   = oci_core_instance.lab_instance
}

moved {
  from = oci_core_volume.lab1_block_volume
  to   = oci_core_volume.lab_block_volume
}

moved {
  from = oci_core_volume_attachment.lab1_volume_attachment
  to   = oci_core_volume_attachment.lab_volume_attachment
}
