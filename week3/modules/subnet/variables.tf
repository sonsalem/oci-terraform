variable "compartment_id" {
  description = "OCID of the compartment where the subnet resources will be created"
  type        = string
}

variable "vcn_id" {
  description = "OCID of the VCN the subnet belongs to"
  type        = string
}

variable "subnet_name" {
  description = "Display name for the subnet"
  type        = string
}

variable "dns_label" {
  description = "DNS label for the subnet (must be unique within the VCN, max 15 chars, alphanumeric)"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "prohibit_public_ip_on_vnic" {
  description = "Whether VNICs in this subnet get private IPs only (true = private subnet, false = public subnet)"
  type        = bool
  default     = true
}

# Route table
variable "route_rules" {
  description = "List of route rules to attach to the subnet's route table"
  type = list(object({
    destination       = string
    destination_type  = optional(string, "CIDR_BLOCK")
    network_entity_id = string
    description       = optional(string, "")
  }))
  default = []
}

# Security list
variable "ingress_rules" {
  description = "List of ingress security rules for the subnet's security list"
  type = list(object({
    protocol    = string # "6" = TCP, "17" = UDP, "1" = ICMP, "all"
    source      = string
    source_type = optional(string, "CIDR_BLOCK")
    description = optional(string, "")
    stateless   = optional(bool, false)
    tcp_options = optional(object({
      min = number
      max = number
    }), null)
    udp_options = optional(object({
      min = number
      max = number
    }), null)
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress security rules for the subnet's security list"
  type = list(object({
    protocol         = string
    destination      = string
    destination_type = optional(string, "CIDR_BLOCK")
    description      = optional(string, "")
    stateless        = optional(bool, false)
  }))
  default = []
}

# Flow logs
variable "enable_flow_logs" {
  description = "Whether to enable VCN Flow Logs for this subnet"
  type        = bool
  default     = false
}

variable "log_group_id" {
  description = "OCID of the Logging log group to attach the subnet flow log to. Required when enable_flow_logs = true"
  type        = string
  default     = null
}

variable "flow_log_retention_days" {
  description = "Retention period (days) for the flow log"
  type        = number
  default     = 30
}

variable "freeform_tags" {
  description = "Freeform tags applied to every resource created by this module"
  type        = map(string)
  default     = {}
}
