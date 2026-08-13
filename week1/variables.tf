variable "lab_name" {
  description = "Prefix applied to the display name of every resource"
  type        = string
  default     = "salem-lab"
}

variable "oci_region" {
  description = "OCI region identifier, must match the region set in ~/.oci/config"
  type        = string
  default     = "me-jeddah-1"
}

variable "compartment_id" {
  description = "OCID of the compartment to deploy into"
  type        = string
}

variable "ssh_pubkey_file" {
  description = "Path to the SSH public key (.pub) installed for the opc user"
  type        = string
  default     = "C:/salem-oci/ssh-key-2026-08-07.key.pub"
}

variable "vcn_cidr" {
  description = "Address range for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Address range for the public subnet, must fall inside vcn_cidr"
  type        = string
  default     = "10.0.0.0/24"
}

variable "vm_shape" {
  description = "Compute shape for the instance"
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "vm_ocpus" {
  description = "OCPU count, only honoured by .Flex shapes"
  type        = number
  default     = 1
}

variable "vm_memory_gb" {
  description = "Memory in GB, only honoured by .Flex shapes"
  type        = number
  default     = 12
}

variable "volume_size_gb" {
  description = "Size of the attached block volume in GB, 50 is the OCI minimum"
  type        = number
  default     = 50
}
