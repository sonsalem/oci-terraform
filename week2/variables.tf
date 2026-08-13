# ---------------------------------------------------------------------------
# Tenancy / provider
# ---------------------------------------------------------------------------

variable "compartment_id" {
  description = "OCID of the compartment every resource is created in. Tenancy-specific, so there is deliberately no default."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.(compartment|tenancy)\\.", var.compartment_id))
    error_message = "compartment_id must be a compartment or tenancy OCID (starts with ocid1.compartment. or ocid1.tenancy.)."
  }
}

variable "oci_region" {
  description = "OCI region identifier, e.g. me-jeddah-1."
  type        = string
  default     = "me-jeddah-1"
}

variable "oci_config_profile" {
  description = "Profile inside ~/.oci/config used for authentication."
  type        = string
  default     = "DEFAULT"
}

variable "availability_domain_index" {
  description = "Which availability domain in the region to use. Bump this if you hit 'Out of host capacity'."
  type        = number
  default     = 0

  validation {
    condition     = var.availability_domain_index >= 0
    error_message = "availability_domain_index must be zero or greater."
  }
}

# ---------------------------------------------------------------------------
# Naming and tagging
# ---------------------------------------------------------------------------

variable "lab_name" {
  description = "Prefix applied to every display name, so one change renames the whole lab."
  type        = string
  default     = "salem-lab-w2"

  validation {
    condition     = length(var.lab_name) > 0 && length(var.lab_name) <= 40
    error_message = "lab_name must be between 1 and 40 characters."
  }
}

variable "freeform_tags" {
  description = "Extra freeform tags merged onto every taggable resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vcn_cidr))
    error_message = "vcn_cidr must be a valid IPv4 CIDR block."
  }
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN. Immutable after creation, so changing it rebuilds the VCN."
  type        = string
  default     = "week2vcn"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.vcn_dns_label))
    error_message = "vcn_dns_label must start with a letter and contain up to 15 lowercase alphanumeric characters."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet that hosts the load balancer. Must sit inside vcn_cidr."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_dns_label" {
  description = "DNS label for the public subnet. Immutable after creation."
  type        = string
  default     = "pubsub"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet that hosts the app instance and the FSS mount target. Must sit inside vcn_cidr."
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr))
    error_message = "private_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_dns_label" {
  description = "DNS label for the private subnet. Immutable after creation."
  type        = string
  default     = "privsub"
}

variable "lb_allowed_cidrs" {
  description = "Source CIDRs allowed to reach the load balancer listener. Narrow this to your own IP for anything longer-lived than a lab."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.lb_allowed_cidrs) > 0
    error_message = "lb_allowed_cidrs must contain at least one CIDR block."
  }
}

variable "ssh_allowed_cidrs" {
  description = "Source CIDRs allowed to SSH into the private instance. Empty means 'inside the VCN only', which is the intended default — the instance has no public IP."
  type        = list(string)
  default     = []
}

variable "ssh_port" {
  description = "TCP port the instance listens on for SSH."
  type        = number
  default     = 22
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

variable "instance_shape" {
  description = "Compute shape for the application instance."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "instance_ocpus" {
  description = "OCPUs allocated to the instance. Flexible shapes only."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_ocpus >= 1
    error_message = "instance_ocpus must be at least 1."
  }
}

variable "instance_memory_gb" {
  description = "Memory in GB allocated to the instance. Flexible shapes only."
  type        = number
  default     = 12
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB. OCI's minimum is 50."
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_size_gb >= 50
    error_message = "boot_volume_size_gb must be at least 50, OCI's minimum."
  }
}

variable "instance_hostname_label" {
  description = "Hostname label for the instance VNIC, used for private DNS inside the VCN."
  type        = string
  default     = "app01"
}

variable "image_operating_system" {
  description = "Operating system used to look up the newest matching platform image."
  type        = string
  default     = "Oracle Linux"
}

variable "image_operating_system_version" {
  description = "OS version used to look up the newest matching platform image."
  type        = string
  default     = "9"
}

variable "ssh_public_key_path" {
  description = "Path to the PUBLIC half of your SSH key pair. Only the public key ever leaves this machine."
  type        = string
  default     = "C:/salem-oci/ssh-key-2026-08-12.key.pub"
}

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

variable "app_name" {
  description = "Name shown on the application's landing page."
  type        = string
  default     = "OCI Terraform Week 2 Lab"
}

variable "app_port" {
  description = "TCP port the application listens on inside the private subnet. Kept separate from lb_listener_port so the load balancer demonstrates port translation."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "app_port must be a valid TCP port."
  }
}

variable "app_mount_point" {
  description = "Directory on the instance where the File Storage export is mounted. The web root points here."
  type        = string
  default     = "/mnt/app"

  validation {
    condition     = startswith(var.app_mount_point, "/")
    error_message = "app_mount_point must be an absolute path."
  }
}

# ---------------------------------------------------------------------------
# File Storage Service
# ---------------------------------------------------------------------------

variable "fss_export_path" {
  description = "Export path advertised by the mount target, e.g. /app. This is the NFS-side path, not the local mount point."
  type        = string
  default     = "/app"

  validation {
    condition     = startswith(var.fss_export_path, "/")
    error_message = "fss_export_path must start with /."
  }
}

variable "fss_export_access" {
  description = "Access level granted to clients in the export options."
  type        = string
  default     = "READ_WRITE"

  validation {
    condition     = contains(["READ_WRITE", "READ_ONLY"], var.fss_export_access)
    error_message = "fss_export_access must be READ_WRITE or READ_ONLY."
  }
}

variable "fss_identity_squash" {
  description = "How client UIDs/GIDs are remapped. NONE keeps them as-is, which is what the app needs to write its files."
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "ROOT", "ALL"], var.fss_identity_squash)
    error_message = "fss_identity_squash must be NONE, ROOT or ALL."
  }
}

variable "fss_require_privileged_source_port" {
  description = "Require NFS clients to connect from a source port below 1024. Linux does this by default."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------

variable "lb_shape" {
  description = "Load balancer shape. 'flexible' bills on the bandwidth range below."
  type        = string
  default     = "flexible"
}

variable "lb_min_bandwidth_mbps" {
  description = "Minimum bandwidth for a flexible load balancer."
  type        = number
  default     = 10
}

variable "lb_max_bandwidth_mbps" {
  description = "Maximum bandwidth for a flexible load balancer."
  type        = number
  default     = 10
}

variable "lb_is_private" {
  description = "Whether the load balancer gets a private IP instead of a public one. False puts it on the internet, which is the point of the public subnet."
  type        = bool
  default     = false
}

variable "lb_listener_port" {
  description = "Port the load balancer listens on for client traffic."
  type        = number
  default     = 80
}

variable "lb_listener_protocol" {
  description = "Listener protocol. HTTP keeps the lab free of certificate management."
  type        = string
  default     = "HTTP"
}

variable "lb_backend_policy" {
  description = "How the backend set distributes traffic across backends."
  type        = string
  default     = "ROUND_ROBIN"

  validation {
    condition     = contains(["ROUND_ROBIN", "LEAST_CONNECTIONS", "IP_HASH"], var.lb_backend_policy)
    error_message = "lb_backend_policy must be ROUND_ROBIN, LEAST_CONNECTIONS or IP_HASH."
  }
}

variable "lb_backend_weight" {
  description = "Relative weight of the backend inside the backend set."
  type        = number
  default     = 1
}

variable "lb_idle_timeout_seconds" {
  description = "How long an idle connection is held open by the listener."
  type        = number
  default     = 60
}

variable "lb_health_check_protocol" {
  description = "Protocol the health checker speaks to the backend."
  type        = string
  default     = "HTTP"
}

variable "lb_health_check_url_path" {
  description = "Path the health checker requests. '/' is served from the File Storage mount, so a broken mount correctly marks the backend unhealthy."
  type        = string
  default     = "/"
}

variable "lb_health_check_return_code" {
  description = "HTTP status the health checker treats as healthy."
  type        = number
  default     = 200
}

variable "lb_health_check_interval_ms" {
  description = "Milliseconds between health checks."
  type        = number
  default     = 10000
}

variable "lb_health_check_timeout_ms" {
  description = "Milliseconds before a single health check attempt times out."
  type        = number
  default     = 3000
}

variable "lb_health_check_retries" {
  description = "Consecutive failures before a backend is marked unhealthy."
  type        = number
  default     = 3
}
