# The resource design in this file is loosely based on the "Regional TCP Load
# Balancer" Terraform module. That module cannot be used directly because it
# assumes a one-to-one mapping between forwarded port and target pool. This
# project requires many forwarded ports for the same target pool.
#
# https://github.com/GoogleCloudPlatform/terraform-google-lb
locals {
  lb_name = "${var.name}-load-balancing"

  forwarded_ports = [for wpt_server_port in var.wpt_server_ports : wpt_server_port.port]
}

resource "google_compute_forwarding_rule" "default" {
  count                 = length(local.forwarded_ports)
  name                  = "${local.lb_name}-${count.index}"
  target                = google_compute_target_pool.default.self_link
  load_balancing_scheme = "EXTERNAL"
  port_range            = local.forwarded_ports[count.index]
  ip_address            = google_compute_address.web-platform-tests-live-address.address
}

resource "google_compute_target_pool" "default" {
  name             = local.lb_name
  region           = var.region
  session_affinity = "CLIENT_IP_PROTO"

  health_checks = [
    google_compute_http_health_check.default.name,
  ]
}

resource "google_compute_http_health_check" "default" {
  name = "${local.lb_name}-health-check"

  # A query parameter is used to distinguish the health check in the server's
  # request logs.
  request_path = "/?gcp-health-check-load-balancing"

  port = var.wpt_server_ports[0].port
}

resource "google_compute_firewall" "default-lb-fw" {
  name    = "${local.lb_name}-vm-service"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = local.forwarded_ports
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.name}-allow"]
}
