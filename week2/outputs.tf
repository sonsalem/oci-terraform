output "load_balancer_public_ip" {
  description = "Public IP of the load balancer, the single entry point into the lab."
  value       = local.load_balancer_ip
}

output "application_url" {
  description = "Open this in a browser once the backend reports healthy."
  value       = "http://${local.load_balancer_ip}:${var.lb_listener_port}/"
}

output "load_balancer_id" {
  description = "OCID of the load balancer, for checking backend health in the Console."
  value       = oci_load_balancer_load_balancer.this.id
}

output "instance_private_ip" {
  description = "Private IP of the application instance. There is no public IP by design."
  value       = oci_core_instance.app.private_ip
}

output "instance_id" {
  description = "OCID of the application instance."
  value       = oci_core_instance.app.id
}

output "mount_target_ip" {
  description = "Private IP of the File Storage mount target, the NFS server address."
  value       = local.mount_target_ip
}

output "nfs_mount_command" {
  description = "How the instance mounts the export. cloud-init already runs this on first boot."
  value       = "mount -t nfs ${local.mount_target_ip}:${var.fss_export_path} ${var.app_mount_point}"
}

output "file_system_id" {
  description = "OCID of the File Storage file system holding the application files."
  value       = oci_file_storage_file_system.app.id
}

output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.this.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet hosting the load balancer."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID of the private subnet hosting the instance and mount target."
  value       = oci_core_subnet.private.id
}

output "availability_domain" {
  description = "Availability domain everything landed in."
  value       = local.availability_domain
}
