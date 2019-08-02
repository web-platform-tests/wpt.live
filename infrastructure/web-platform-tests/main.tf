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
  source = "github.com/terraform-google-modules/terraform-google-container-vm"

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
  source = "github.com/terraform-google-modules/terraform-google-container-vm"

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
  source = "github.com/bocoup/terraform-google-multi-port-managed-instance-group?ref=c87b27fa7"

  providers {
    google-beta = "google-beta"
  }

  region        = "${var.region}"
  zone          = "${var.zone}"
  name          = "${var.name}-wpt-servers"
  size          = 2
  compute_image = "${module.wpt-server-container.source_image}"

  # The default "f1-micro" instance was found to be underpowered for running
  # WPT and synchronizing submissions as of 2019-07-31 [1].
  #
  # [1] WPT commit 91e90a3a5fbd8161c3c4d9637466c23895752db9
  machine_type = "g1-small"

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

  service_port_1         = 80
  service_port_1_name    = "http-primary"
  service_port_2         = 8000
  service_port_2_name    = "http-secondary"
  service_port_3         = 443
  service_port_3_name    = "https"
  service_port_4         = 8001
  service_port_4_name    = "http2"
  service_port_5         = 8002
  service_port_5_name    = "websocket"
  service_port_6         = 8003
  service_port_6_name    = "websocket-secure"
  ssh_fw_rule            = false
  https_health_check     = true
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
