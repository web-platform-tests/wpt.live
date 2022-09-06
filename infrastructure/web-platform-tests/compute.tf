# Contains the configurations for the Compute Engine section of Google Cloud
# These configurations come from modules that are now archived:
# - Cert Renewer used: github.com/dcaba/terraform-google-managed-instance-group
# - WPT Server used: github.com/ecosystem-infra/terraform-google-multi-port-managed-instance-group
# Most hardcoded defaults come from those aforementioned modules.

########################################
# WPT Server
# These configurations come from: github.com/ecosystem-infra/terraform-google-multi-port-managed-instance-group
# More information about how it was used previously: https://github.com/web-platform-tests/wpt.live/blob/67dc5976ccce2e64483f2028a35659d4d6e58891/infrastructure/web-platform-tests/main.tf#L69-L137
########################################

resource "google_compute_health_check" "wpt_health_check" {
  name = "${var.name}-wpt-servers"

  check_interval_sec  = 10
  timeout_sec         = 10
  healthy_threshold   = 3
  unhealthy_threshold = 6

  https_health_check {
    port = "443"
    # A query parameter is used to distinguish the health check in the server's
    # request logs.
    request_path = "/?gcp-health-check"
  }
}

resource "google_compute_instance_group_manager" "wpt_servers" {
  name               = "${var.name}-wpt-servers"
  zone               = var.zone
  description        = "compute VM Instance Group"
  wait_for_instances = false
  base_instance_name = "${var.name}-wpt-servers"
  version {
    name              = "${var.name}-wpt-servers-default"
    instance_template = google_compute_instance_template.wpt_server.self_link
  }
  update_policy {
    type                  = local.update_policy.type
    minimal_action        = local.update_policy.minimal_action
    max_unavailable_fixed = local.update_policy.max_unavailable_fixed
  }
  target_pools = [google_compute_target_pool.default.self_link]
  target_size  = 2

  dynamic "named_port" {
    for_each = var.wpt_server_ports
    content {
      name = named_port.value["name"]
      port = named_port.value["port"]
    }
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.wpt_health_check.self_link
    initial_delay_sec = 30
  }
}

resource "google_compute_firewall" "wpt-server-mig-health-check" {
  name    = "${var.name}-wpt-servers-vm-hc"
  network = var.network_name

  allow {
    protocol = "tcp"
    # https port
    ports = [var.wpt_server_ports[2].port]
  }

  # This range comes from this module that was used previously:
  # https://github.com/Ecosystem-Infra/terraform-google-multi-port-managed-instance-group/blob/master/main.tf#L347
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["${var.name}-allow"]
}

resource "google_compute_firewall" "wpt-servers-default-ssh" {
  name    = "${var.name}-wpt-servers-vm-ssh"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

resource "google_compute_instance_template" "wpt_server" {
  name_prefix = "default-"

  tags = ["allow-ssh", "${var.name}-allow"]

  # As of 2020-06-17, we were running into OOM issues with the 1.7 GB
  # "g1-small" instance[1]. This was suspected to be due to 'git gc' needing
  # more memory, so we upgraded to "e2-medium" (4 GB of RAM).
  #
  # [1] https://github.com/web-platform-tests/wpt.live/issues/30
  machine_type = "e2-medium"

  # The "google-logging-enabled" metadata is undocumented, but it is apparently
  # necessary to enable the capture of logs from the Docker image.
  #
  # https://github.com/GoogleCloudPlatform/konlet/issues/56
  labels = {
    "${module.wpt-server-container.vm_container_label_key}" = module.wpt-server-container.vm_container_label
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnetwork_name
    access_config {
      network_tier = "PREMIUM"
    }
  }

  can_ip_forward = false

  // Create a new boot disk from an image
  disk {
    auto_delete  = true
    boot         = true
    source_image = module.wpt-server-container.source_image
    type         = "PERSISTENT"
    disk_type    = "pd-ssd"
    disk_size_gb = var.wpt_server_disk_size
    mode         = "READ_WRITE"
  }

  service_account {
    email  = "default"
    scopes = ["storage-ro", "logging-write"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  # startup-script and tf_depends_id comes from the module previously used for wpt-server. (see link at top)
  # TODO: evaluate if those two should be removed.
  metadata = {
    "${module.wpt-server-container.metadata_key}" = module.wpt-server-container.metadata_value
    "startup-script"                              = ""
    "tf_depends_id"                               = ""
    "google-logging-enabled"                      = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

########################################
# Cert Renewers
# These configurations come from: github.com/dcaba/terraform-google-managed-instance-group
# More information about how it was used previously: https://github.com/web-platform-tests/wpt.live/blob/67dc5976ccce2e64483f2028a35659d4d6e58891/infrastructure/web-platform-tests/main.tf#L139-L178
########################################

resource "google_compute_instance_template" "cert_renewers" {
  name_prefix = "default-"

  machine_type = "f1-micro"

  region = var.region

  tags = ["allow-ssh", "${var.name}-allow"]

  labels = {
    "${module.cert-renewer-container.vm_container_label_key}" = module.cert-renewer-container.vm_container_label
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnetwork_name
    network_ip = ""
    access_config {
      network_tier = "PREMIUM"
    }
  }

  can_ip_forward = false

  disk {
    auto_delete  = true
    boot         = true
    source_image = module.cert-renewer-container.source_image
    type         = "PERSISTENT"
    disk_type    = "pd-ssd"
    mode         = "READ_WRITE"
  }

  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  # startup-script and tf_depends_id comes from the module previously used for cert renewer. (see link at top)
  # TODO: evaluate if those two should be removed.
  metadata = {
    "${module.cert-renewer-container.metadata_key}" = module.cert-renewer-container.metadata_value
    "startup-script"                                = ""
    "tf_depends_id"                                 = ""
    "google-logging-enabled"                        = "true"
  }

  scheduling {
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "cert_renewers" {
  name               = "${var.name}-cert-renewers"
  description        = "compute VM Instance Group"
  wait_for_instances = false

  base_instance_name = "${var.name}-cert-renewers"

  version {
    instance_template = google_compute_instance_template.cert_renewers.self_link
  }

  zone = var.zone

  update_policy {
    type                  = local.update_policy.type
    minimal_action        = local.update_policy.minimal_action
    max_unavailable_fixed = local.update_policy.max_unavailable_fixed
  }

  target_pools = []

  target_size = 1

  dynamic "named_port" {
    for_each = var.cert_renewer_ports
    content {
      name = named_port.value["name"]
      port = named_port.value["port"]
    }
  }
}
