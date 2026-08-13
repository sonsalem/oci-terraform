output "instance_public_ip" {
  description = "Public IP address of the compute instance"
  value       = oci_core_instance.lab_instance.public_ip
}

output "instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.lab_instance.id
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.lab_vcn.id
}

output "subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.lab_public_subnet.id
}

output "block_volume_id" {
  description = "OCID of the block volume"
  value       = oci_core_volume.lab_block_volume.id
}

# Private key path is derived by dropping the .pub suffix, so it stays correct
# if ssh_pubkey_file changes.
output "ssh_connection_command" {
  description = "Ready-to-use SSH command to connect to the instance"
  value       = "ssh -i ${trimsuffix(var.ssh_pubkey_file, ".pub")} opc@${oci_core_instance.lab_instance.public_ip}"
}
