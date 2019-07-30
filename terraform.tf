locals {
  region            = "us-central1"
  zone              = "us-central1-b"
  project_name      = "wptdashboard"
  tot_host_name     = "wheresbob.org"
  tot_alt_host_name = "thecolbert.report"
  tot_bucket_name   = "web-platform-tests-tot"
}

provider "google" {
  project     = "${local.project_name}"
  region      = "${local.region}"
  credentials = "${file("google-cloud-platform-credentials.json")}"
}

provider "google-beta" {
  project     = "${local.project_name}"
  region      = "${local.region}"
  credentials = "${file("google-cloud-platform-credentials.json")}"
}

resource "google_compute_network" "default" {
  name                    = "web-platform-tests-live-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "default" {
  name                     = "web-platform-tests-live-subnetwork"
  ip_cidr_range            = "10.127.0.0/20"
  network                  = "${google_compute_network.default.self_link}"
  region                   = "${local.region}"
  private_ip_google_access = true
}

module "wpt-server-tot-image" {
  source   = "./infrastructure/docker-image"
  registry = "gcr.io"
  image    = "${local.project_name}/web-platform-tests-live-wpt-server-tot"
}

module "cert-renewer-image" {
  source   = "./infrastructure/docker-image"
  registry = "gcr.io"
  image    = "${local.project_name}/web-platform-tests-live-cert-renewer"
}

module "web-platform-tests-live" {
  source = "./infrastructure/web-platform-tests"

  providers {
    google-beta = "google-beta"
  }

  name               = "web-platform-tests-tot"
  network_name       = "${google_compute_network.default.name}"
  subnetwork_name    = "${google_compute_subnetwork.default.name}"
  bucket_name        = "${local.tot_bucket_name}"
  host_zone_name     = "web-platform-tests-tot-host"
  host_name          = "${local.tot_host_name}"
  alt_host_zone_name = "web-platform-tests-tot-alt-host"
  alt_host_name      = "${local.tot_alt_host_name}"
  region             = "${local.region}"
  zone               = "${local.zone}"

  wpt_server_image   = "${module.wpt-server-tot-image.identifier}"
  cert_renewer_image = "${module.cert-renewer-image.identifier}"
}

output "web-platform-tests-live-address" {
  value = "${module.web-platform-tests-live.address}"
}
