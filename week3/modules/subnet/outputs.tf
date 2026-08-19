output "subnet_id" {
  description = "OCID of the created subnet"
  value       = oci_core_subnet.this.id
}

output "subnet_cidr_block" {
  value = oci_core_subnet.this.cidr_block
}

output "route_table_id" {
  value = oci_core_route_table.this.id
}

output "security_list_id" {
  value = oci_core_security_list.this.id
}

output "flow_log_id" {
  description = "OCID of the flow log, null when enable_flow_logs = false"
  value       = try(oci_logging_log.flow_log[0].id, null)
}
