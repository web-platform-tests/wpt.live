# https://github.com/hashicorp/terraform/issues/17399
provider "google-beta" {}

locals {
  update_policy = [
    {
      type = "OPPORTUNISTIC"
      minimal_action = "REPLACE"
    }
  ]
}

module "wpt-servers" {
  source                 = "github.com/bocoup/terraform-google-multi-port-managed-instance-group?ref=3b94da2"
  providers {
    google-beta = "google-beta"
  }
  region                 = "${var.region}"
  zone                   = "${var.zone}"
  name                   = "${var.network_name}-group1"
  size                   = 2
  compute_image          = "${var.wpt_server_machine_image}"
  instance_labels        = "${var.wpt_server_instance_labels}"
  metadata               = "${var.wpt_server_instance_metadata}"
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
  http_health_check      = true
  target_pools           = ["${google_compute_target_pool.default.self_link}"]
  target_tags            = ["allow-service1"]
  network                = "${var.network_name}"
  subnetwork             = "${var.subnetwork_name}"
  service_account_scopes = ["storage-ro", "logging-write"]
  update_policy          = "${local.update_policy}"
}

module "cert-renewers" {
  # https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group/pull/39
  source                 = "github.com/dcaba/terraform-google-managed-instance-group?ref=340409c"
  providers {
    google-beta = "google-beta"
  }
  region                 = "${var.region}"
  zone                   = "${var.zone}"
  name                   = "${var.network_name}-group2"
  size                   = 1
  compute_image          = "${var.cert_renewer_machine_image}"
  instance_labels        = "${var.cert_renewer_instance_labels}"
  metadata               = "${var.cert_renewer_instance_metadata}"
  service_port           = 8004
  service_port_name      = "http"
  ssh_fw_rule            = false
  http_health_check      = false
  target_tags            = ["allow-service1"]
  network                = "${var.network_name}"
  subnetwork             = "${var.subnetwork_name}"
  service_account_scopes = ["cloud-platform"]
  update_policy          = "${local.update_policy}"
}

resource "google_storage_bucket" "persistance" {
  name = "${var.bucket_name}"
}
