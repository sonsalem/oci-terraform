############################################
# Root main.tf
# Wires the reusable Subnet and OKE modules
# together to build the Week 3 lab:
#   - VCN + gateways
#   - 4x subnets via the subnet module
#     (endpoint / workers / pods / LB)
#   - OKE cluster + managed node pool with
#     VCN-native pod networking via the OKE
#     module
############################################

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# ---------------- VCN ----------------

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr_block]
  display_name   = "${var.cluster_name}-vcn"
  dns_label      = var.vcn_dns_label
  freeform_tags  = var.freeform_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.cluster_name}-igw"
  enabled        = true
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.cluster_name}-natgw"
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.cluster_name}-sgw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# ---------------- Logging (used by subnet module flow logs) ----------------

resource "oci_logging_log_group" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.cluster_name}-log-group"
}

# ---------------- Subnets (Subnet module x4) ----------------

module "endpoint_subnet" {
  source = "./modules/subnet"

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  subnet_name                = "${var.cluster_name}-endpoint"
  dns_label                  = "endpoint"
  cidr_block                 = var.endpoint_subnet_cidr
  prohibit_public_ip_on_vnic = false
  enable_flow_logs           = var.enable_flow_logs
  log_group_id               = oci_logging_log_group.this.id
  freeform_tags              = var.freeform_tags

  route_rules = [
    {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_internet_gateway.this.id
      description       = "default route to internet gateway"
    }
  ]

  ingress_rules = [
    { protocol = "6", source = "0.0.0.0/0", description = "Kubernetes API (443)", tcp_options = { min = 443, max = 443 } },
    { protocol = "6", source = "0.0.0.0/0", description = "Kubernetes API legacy (6443)", tcp_options = { min = 6443, max = 6443 } },
    { protocol = "6", source = var.worker_subnet_cidr, description = "Worker to control plane", tcp_options = { min = 12250, max = 12250 } },
  ]

  egress_rules = [
    { protocol = "all", destination = "0.0.0.0/0", description = "allow all egress" },
  ]
}

module "worker_subnet" {
  source = "./modules/subnet"

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  subnet_name                = "${var.cluster_name}-workers"
  dns_label                  = "workers"
  cidr_block                 = var.worker_subnet_cidr
  prohibit_public_ip_on_vnic = true
  enable_flow_logs           = var.enable_flow_logs
  log_group_id               = oci_logging_log_group.this.id
  freeform_tags              = var.freeform_tags

  route_rules = [
    {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_nat_gateway.this.id
      description       = "default route to NAT gateway"
    },
    {
      destination       = data.oci_core_services.all_services.services[0].cidr_block
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.this.id
      description       = "route to OCI services via service gateway"
    }
  ]

  ingress_rules = [
    { protocol = "all", source = var.vcn_cidr_block, description = "allow all traffic within the VCN" },
  ]

  egress_rules = [
    { protocol = "all", destination = "0.0.0.0/0", description = "allow all egress" },
  ]
}

module "pod_subnet" {
  source = "./modules/subnet"

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  subnet_name                = "${var.cluster_name}-pods"
  dns_label                  = "pods"
  cidr_block                 = var.pod_subnet_cidr
  prohibit_public_ip_on_vnic = true
  enable_flow_logs           = var.enable_flow_logs
  log_group_id               = oci_logging_log_group.this.id
  freeform_tags              = var.freeform_tags

  route_rules = [
    {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_nat_gateway.this.id
      description       = "default route to NAT gateway"
    }
  ]

  ingress_rules = [
    { protocol = "all", source = var.vcn_cidr_block, description = "allow all traffic within the VCN (pod-to-pod / pod-to-worker)" },
  ]

  egress_rules = [
    { protocol = "all", destination = "0.0.0.0/0", description = "allow all egress" },
  ]
}

module "lb_subnet" {
  source = "./modules/subnet"

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  subnet_name                = "${var.cluster_name}-lb"
  dns_label                  = "lb"
  cidr_block                 = var.lb_subnet_cidr
  prohibit_public_ip_on_vnic = false
  enable_flow_logs           = var.enable_flow_logs
  log_group_id               = oci_logging_log_group.this.id
  freeform_tags              = var.freeform_tags

  route_rules = [
    {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_internet_gateway.this.id
      description       = "default route to internet gateway"
    }
  ]

  ingress_rules = [
    { protocol = "6", source = "0.0.0.0/0", description = "HTTP", tcp_options = { min = 80, max = 80 } },
    { protocol = "6", source = "0.0.0.0/0", description = "HTTPS", tcp_options = { min = 443, max = 443 } },
  ]

  egress_rules = [
    { protocol = "all", destination = "0.0.0.0/0", description = "allow all egress" },
  ]
}

# ---------------- Kubernetes version ----------------

# The provider requires a concrete version, so "leave it null for the latest"
# is resolved here against what OKE actually offers in this region rather than
# being hardcoded and going stale.
data "oci_containerengine_cluster_option" "this" {
  cluster_option_id = "all"
  compartment_id    = var.compartment_id
}

locals {
  available_kubernetes_versions = data.oci_containerengine_cluster_option.this.kubernetes_versions

  kubernetes_version = coalesce(
    var.kubernetes_version,
    element(local.available_kubernetes_versions, length(local.available_kubernetes_versions) - 1),
  )
}

# ---------------- Node pool image (latest available for the shape) ----------------

data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_id
}

locals {
  # An OKE worker image is tied to a Kubernetes version, so it has to match the
  # version the cluster is created with. aarch64 and GPU images are excluded so
  # an x86 shape like VM.Standard.E5.Flex never gets an incompatible image.
  node_image_candidates = [
    for source in data.oci_containerengine_node_pool_option.this.sources :
    source.image_id
    if length(regexall("OKE-${trimprefix(local.kubernetes_version, "v")}", source.source_name)) > 0
    && length(regexall("aarch64|GPU", source.source_name)) == 0
  ]

  node_image_id = local.node_image_candidates[0]
}

# ---------------- OKE module ----------------

module "oke" {
  source = "./modules/oke"

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id

  cluster_name       = var.cluster_name
  kubernetes_version = local.kubernetes_version

  api_endpoint_subnet_id           = module.endpoint_subnet.subnet_id
  is_public_ip_enabled_on_endpoint = true
  service_lb_subnet_ids            = [module.lb_subnet.subnet_id]

  cni_type          = "OCI_VCN_IP_NATIVE"
  worker_subnet_id  = module.worker_subnet.subnet_id
  pod_subnet_id     = module.pod_subnet.subnet_id
  max_pods_per_node = 31

  availability_domains = [
    for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name
  ]

  node_pool_name     = "${var.cluster_name}-pool"
  node_shape         = var.node_shape
  node_ocpus         = var.node_ocpus
  node_memory_in_gbs = var.node_memory_in_gbs
  node_pool_size     = var.node_pool_size
  node_image_id      = local.node_image_id
  ssh_public_key     = var.ssh_public_key_path != "" ? file(var.ssh_public_key_path) : ""

  freeform_tags = var.freeform_tags
}
