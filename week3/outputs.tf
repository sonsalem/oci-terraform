output "cluster_id" {
  value = module.oke.cluster_id
}

output "cluster_name" {
  value = module.oke.cluster_name
}

output "node_pool_id" {
  value = module.oke.node_pool_id
}

output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "worker_subnet_id" {
  value = module.worker_subnet.subnet_id
}

output "pod_subnet_id" {
  value = module.pod_subnet.subnet_id
}

output "lb_subnet_id" {
  value = module.lb_subnet.subnet_id
}

output "get_kubeconfig_command" {
  description = "Run this after apply to configure kubectl"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0"
}
