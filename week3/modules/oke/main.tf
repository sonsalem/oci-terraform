############################################
# modules/oke/main.tf
#
# Creates an OKE cluster + a managed worker
# node pool with VCN-native pod networking.
# Fully driven by variables - no hardcoded
# values - so the module can be reused for
# dev/staging/prod by simply changing the
# root configuration's inputs.
############################################

# ---------------- Cluster ----------------

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  name               = var.cluster_name
  vcn_id             = var.vcn_id
  kubernetes_version = var.kubernetes_version
  type               = var.cluster_type
  freeform_tags      = var.freeform_tags

  endpoint_config {
    is_public_ip_enabled = var.is_public_ip_enabled_on_endpoint
    subnet_id            = var.api_endpoint_subnet_id
  }

  # The cluster must advertise the same CNI the node pool asks for. Omitting
  # this silently defaults the cluster to FLANNEL_OVERLAY, which then rejects a
  # VCN-native node pool with "pod network options didn't match".
  cluster_pod_network_options {
    cni_type = var.cni_type
  }

  options {
    service_lb_subnet_ids = var.service_lb_subnet_ids

    # Conditional expression: only relevant for the overlay CNI.
    # For OCI_VCN_IP_NATIVE, pods get real VCN IPs from the pod subnet instead.
    kubernetes_network_config {
      pods_cidr     = var.cni_type == "FLANNEL_OVERLAY" ? var.pods_cidr : null
      services_cidr = var.services_cidr
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }
}

# ---------------- Managed Worker Node Pool ----------------

resource "oci_containerengine_node_pool" "this" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_id
  kubernetes_version = var.kubernetes_version
  name               = var.node_pool_name
  node_shape         = var.node_shape
  freeform_tags      = var.freeform_tags

  # Conditional block: flex-shape sizing is only supplied when a
  # *.Flex shape is used, matching how OCI's own API behaves.
  dynamic "node_shape_config" {
    for_each = length(regexall("Flex", var.node_shape)) > 0 ? [1] : []
    content {
      ocpus         = var.node_ocpus
      memory_in_gbs = var.node_memory_in_gbs
    }
  }

  node_source_details {
    image_id                = var.node_image_id
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : null

  node_config_details {
    size = var.node_pool_size

    # Dynamic block: spread nodes across every AD passed in.
    dynamic "placement_configs" {
      for_each = var.availability_domains
      content {
        availability_domain = placement_configs.value
        subnet_id           = var.worker_subnet_id
      }
    }

    nsg_ids = var.worker_nsg_ids

    # VCN-native pod networking configuration.
    # Only created when cni_type = OCI_VCN_IP_NATIVE (conditional block).
    dynamic "node_pool_pod_network_option_details" {
      for_each = var.cni_type == "OCI_VCN_IP_NATIVE" ? [1] : []
      content {
        cni_type          = "OCI_VCN_IP_NATIVE"
        pod_subnet_ids    = [var.pod_subnet_id]
        max_pods_per_node = var.max_pods_per_node
      }
    }
  }

  initial_node_labels {
    key   = "name"
    value = var.cluster_name
  }
}
