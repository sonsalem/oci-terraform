# ---------------------------------------------------------------------------
# Application Load Balancer (OCI Load Balancer service, layer 7)
#
# Lives in the public subnet with a public IP. It is the only thing in this lab
# reachable from the internet, and it forwards to a backend that has no public
# address of its own.
# ---------------------------------------------------------------------------

resource "oci_load_balancer_load_balancer" "this" {
  compartment_id = var.compartment_id
  display_name   = local.names.load_balancer
  shape          = var.lb_shape
  subnet_ids     = [oci_core_subnet.public.id]
  is_private     = var.lb_is_private
  freeform_tags  = local.common_tags

  # shape_details is only valid on the flexible shape, so it is generated
  # conditionally rather than assumed.
  dynamic "shape_details" {
    for_each = var.lb_shape == "flexible" ? [1] : []

    content {
      minimum_bandwidth_in_mbps = var.lb_min_bandwidth_mbps
      maximum_bandwidth_in_mbps = var.lb_max_bandwidth_mbps
    }
  }
}

resource "oci_load_balancer_backend_set" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = local.names.backend_set
  policy           = var.lb_backend_policy

  # The check requests lb_health_check_url_path, which nginx serves out of the
  # File Storage mount. If the NFS mount breaks, the backend goes unhealthy —
  # which is the behaviour you want.
  health_checker {
    protocol          = var.lb_health_check_protocol
    port              = var.app_port
    url_path          = var.lb_health_check_url_path
    return_code       = var.lb_health_check_return_code
    interval_ms       = var.lb_health_check_interval_ms
    timeout_in_millis = var.lb_health_check_timeout_ms
    retries           = var.lb_health_check_retries
  }
}

resource "oci_load_balancer_backend" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  backendset_name  = oci_load_balancer_backend_set.app.name

  # The private IP, because that is the only address this instance has.
  ip_address = oci_core_instance.app.private_ip
  port       = var.app_port
  weight     = var.lb_backend_weight

  backup  = false
  drain   = false
  offline = false
}

resource "oci_load_balancer_listener" "app" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = local.names.listener
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = var.lb_listener_port
  protocol                 = var.lb_listener_protocol

  connection_configuration {
    idle_timeout_in_seconds = var.lb_idle_timeout_seconds
  }
}
