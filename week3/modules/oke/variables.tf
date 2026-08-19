variable "compartment_id" {
  type = string
}

variable "vcn_id" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "oke-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. v1.29.1. Leave null to use the latest supported version."
  type        = string
  default     = null
}

variable "cluster_type" {
  description = "BASIC_CLUSTER or ENHANCED_CLUSTER"
  type        = string
  default     = "BASIC_CLUSTER"
}

# Networking
variable "api_endpoint_subnet_id" {
  description = "Subnet OCID for the Kubernetes API endpoint"
  type        = string
}

variable "is_public_ip_enabled_on_endpoint" {
  type    = bool
  default = false
}

variable "service_lb_subnet_ids" {
  description = "Subnet OCID(s) used by OKE to provision LoadBalancer services"
  type        = list(string)
}

variable "pods_cidr" {
  description = "CIDR used for pods when cni_type is FLANNEL_OVERLAY. Ignored for VCN-native."
  type        = string
  default     = "10.244.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.96.0.0/16"
}

# Node pool and pod networking
variable "cni_type" {
  description = "OCI_VCN_IP_NATIVE (VCN-native pod networking) or FLANNEL_OVERLAY"
  type        = string
  default     = "OCI_VCN_IP_NATIVE"

  validation {
    condition     = contains(["OCI_VCN_IP_NATIVE", "FLANNEL_OVERLAY"], var.cni_type)
    error_message = "cni_type must be OCI_VCN_IP_NATIVE or FLANNEL_OVERLAY."
  }
}

variable "worker_subnet_id" {
  description = "Subnet OCID where worker node VNICs are placed"
  type        = string
}

variable "pod_subnet_id" {
  description = "Subnet OCID used for pod IPs when cni_type = OCI_VCN_IP_NATIVE"
  type        = string
  default     = null
}

variable "max_pods_per_node" {
  type    = number
  default = 31
}

variable "availability_domains" {
  description = "List of Availability Domain names to spread the node pool across"
  type        = list(string)
}

variable "node_pool_name" {
  type    = string
  default = "oke-node-pool"
}

variable "node_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "node_ocpus" {
  description = "Only used when node_shape is a *.Flex shape"
  type        = number
  default     = 2
}

variable "node_memory_in_gbs" {
  description = "Only used when node_shape is a *.Flex shape"
  type        = number
  default     = 16
}

variable "node_pool_size" {
  type    = number
  default = 3
}

variable "node_image_id" {
  description = "OCID of the OKE worker node image (get via oci_containerengine_node_pool_option data source)"
  type        = string
}

variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
}

variable "ssh_public_key" {
  description = "SSH public key for worker node access. Leave empty string to skip."
  type        = string
  default     = ""
}

variable "worker_nsg_ids" {
  type    = list(string)
  default = []
}

variable "freeform_tags" {
  type    = map(string)
  default = {}
}
