# https://github.com/hashicorp/terraform/issues/17399
provider "google-beta" {}

locals {
  bucket_name = "${var.name}-certificates"

  update_policy = [
    {
      type           = "PROACTIVE"
      minimal_action = "RESTART"

      # > maxUnavailable must be greater than 0 when minimal action is set to
      # > RESTART
      max_unavailable_fixed = 1
    },
  ]
}

module "wpt-server-container" {
  source = "github.com/terraform-google-modules/terraform-google-container-vm?ref=v0.3.0"

  container = {
    image = "${var.wpt_server_image}"

    env = [
      {
        name  = "WPT_HOST"
        value = "${var.host_name}"
      },
      {
        name  = "WPT_ALT_HOST"
        value = "${var.alt_host_name}"
      },
      {
        name  = "WPT_BUCKET"
        value = "${local.bucket_name}"
      },
    ]
  }

  restart_policy = "Always"
}

module "cert-renewer-container" {
  source = "github.com/terraform-google-modules/terraform-google-container-vm?ref=v0.3.0"

  container = {
    image = "${var.cert_renewer_image}"

    env = [
      {
        name  = "WPT_HOST"
        value = "${var.host_name}"
      },
      {
        name  = "WPT_ALT_HOST"
        value = "${var.alt_host_name}"
      },
      {
        name  = "WPT_BUCKET"
        value = "${local.bucket_name}"
      },
    ]
  }

  restart_policy = "Always"
}

module "wpt-servers" {
  source = "github.com/ecosystem-infra/terraform-google-multi-port-managed-instance-group?ref=a40a3b9f3"

  providers {
    google-beta = "google-beta"
  }

  region        = "${var.region}"
  zone          = "${var.zone}"
  name          = "${var.name}-wpt-servers"
  size          = 2
  compute_image = "${module.wpt-server-container.source_image}"

  # As of 2020-06-17, we were running into OOM issues with the 1.7 GB
  # "g1-small" instance[1]. This was suspected to be due to 'git gc' needing
  # more memory, so we upgraded to "e2-medium" (4 GB of RAM).
  #
  # [1] https://github.com/web-platform-tests/wpt.live/issues/30
  machine_type = "e2-medium"

  instance_labels = "${map(
    module.wpt-server-container.vm_container_label_key,
    module.wpt-server-container.vm_container_label
  )}"

  # The "google-logging-enabled" metadata is undocumented, but it is apparently
  # necessary to enable the capture of logs from the Docker image.
  #
  # https://github.com/GoogleCloudPlatform/konlet/issues/56
  metadata = "${map(
    module.wpt-server-container.metadata_key,
    module.wpt-server-container.metadata_value,
    "google-logging-enabled",
    "true"
  )}"

  service_port_1      = 80
  service_port_1_name = "http-primary"
  service_port_2      = 8000
  service_port_2_name = "http-secondary"
  service_port_3      = 443
  service_port_3_name = "https"
  service_port_4      = 8001
  service_port_4_name = "http2"
  service_port_5      = 8002
  service_port_5_name = "websocket"
  service_port_6      = 8003
  service_port_6_name = "websocket-secure"
  service_port_7      = 8443
  service_port_7_name = "https-secondary"
  ssh_fw_rule         = false
  https_health_check  = true

  # A query parameter is used to distinguish the health check in the server's
  # request logs.
  hc_path = "/?gcp-health-check"

  hc_port                = 443
  hc_interval            = 10
  hc_healthy_threshold   = 3
  hc_unhealthy_threshold = 6
  target_pools           = ["${google_compute_target_pool.default.self_link}"]
  target_tags            = ["${var.name}-allow"]
  network                = "${var.network_name}"
  subnetwork             = "${var.subnetwork_name}"
  service_account_scopes = ["storage-ro", "logging-write"]
  update_policy          = "${local.update_policy}"
  disk_size_gb           = "${var.wpt_server_disk_size}"
}

module "cert-renewers" {
  # https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group/pull/39
  source = "github.com/dcaba/terraform-google-managed-instance-group?ref=340409c"

  providers {
    google-beta = "google-beta"
  }

  region        = "${var.region}"
  zone          = "${var.zone}"
  name          = "${var.name}-cert-renewers"
  size          = 1
  compute_image = "${module.cert-renewer-container.source_image}"

  instance_labels = "${map(
    module.cert-renewer-container.vm_container_label_key,
    module.cert-renewer-container.vm_container_label
  )}"

  # The "google-logging-enabled" metadata is undocumented, but it is apparently
  # necessary to enable the capture of logs from the Docker image.
  #
  # https://github.com/GoogleCloudPlatform/konlet/issues/56
  metadata = "${map(
    module.cert-renewer-container.metadata_key,
    module.cert-renewer-container.metadata_value,
    "google-logging-enabled",
    "true"
  )}"

  service_port           = 8004
  service_port_name      = "http"
  ssh_fw_rule            = false
  http_health_check      = false
  target_tags            = ["${var.name}-allow"]
  network                = "${var.network_name}"
  subnetwork             = "${var.subnetwork_name}"
  service_account_scopes = ["cloud-platform"]
  update_policy          = "${local.update_policy}"
}

resource "google_storage_bucket" "certificates" {
  name = "${local.bucket_name}"
}
