# Auth — the provider reads the real credentials from ~/.oci/config.

variable "oci_config_profile" {
  description = "Profile inside ~/.oci/config used for authentication"
  type        = string
  default     = "DEFAULT"
}

variable "region" {
  description = "OCI region identifier, must match the region in ~/.oci/config"
  type        = string
  default     = "me-jeddah-1"
}

variable "compartment_id" {
  description = "Compartment where every resource in this lab will be created"
  type        = string
}

# Networking
variable "vcn_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  type    = string
  default = "okelab"
}

variable "endpoint_subnet_cidr" {
  type    = string
  default = "10.0.0.0/28"
}

variable "worker_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "pod_subnet_cidr" {
  description = "Needs to be large: with VCN-native networking every pod consumes a real IP"
  type        = string
  default     = "10.0.16.0/20"
}

variable "lb_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

# OKE
variable "cluster_name" {
  type    = string
  default = "week3-oke-lab"
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "node_pool_size" {
  type    = number
  default = 3
}

variable "node_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "node_ocpus" {
  type    = number
  default = 2
}

variable "node_memory_in_gbs" {
  type    = number
  default = 16
}

variable "ssh_public_key_path" {
  description = "Path to the PUBLIC half of your SSH key pair, installed on the worker nodes. Empty string skips node SSH access."
  type        = string
  default     = ""
}

variable "freeform_tags" {
  type = map(string)
  default = {
    project = "week3-devops-lab"
  }
}
