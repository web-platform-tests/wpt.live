locals {
  region       = "us-central1"
  zone         = "us-central1-b"
  project_name = "wptserve"
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
  name                    = "wpt-live-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "default" {
  name                     = "wpt-live-subnetwork"
  ip_cidr_range            = "10.127.0.0/20"
  network                  = "${google_compute_network.default.self_link}"
  region                   = "${local.region}"
  private_ip_google_access = true
}

module "wpt-server-tot-image" {
  source   = "./infrastructure/docker-image"
  registry = "gcr.io"
  image    = "${local.project_name}/wpt-live-wpt-server-tot"
}

module "wpt-server-submissions-image" {
  source   = "./infrastructure/docker-image"
  registry = "gcr.io"
  image    = "${local.project_name}/wpt-live-wpt-server-submissions"
}

module "cert-renewer-image" {
  source   = "./infrastructure/docker-image"
  registry = "gcr.io"
  image    = "${local.project_name}/wpt-live-cert-renewer"
}

module "wpt-live" {
  source = "./infrastructure/web-platform-tests"

  providers {
    google-beta = "google-beta"
  }

  name               = "wpt-tot"
  network_name       = "${google_compute_network.default.name}"
  subnetwork_name    = "${google_compute_subnetwork.default.name}"
  host_zone_name     = "wpt-live"
  host_name          = "wpt.live"
  alt_host_zone_name = "not-wpt-live"
  alt_host_name      = "not-wpt.live"
  region             = "${local.region}"
  zone               = "${local.zone}"

  wpt_server_image   = "${module.wpt-server-tot-image.identifier}"
  cert_renewer_image = "${module.cert-renewer-image.identifier}"
}

module "wpt-submissions" {
  source = "./infrastructure/web-platform-tests"

  providers {
    google-beta = "google-beta"
  }

  name               = "wpt-submissions"
  network_name       = "${google_compute_network.default.name}"
  subnetwork_name    = "${google_compute_subnetwork.default.name}"
  host_zone_name     = "wptpr-live"
  host_name          = "wptpr.live"
  alt_host_zone_name = "not-wptpr-live"
  alt_host_name      = "not-wptpr.live"
  region             = "${local.region}"
  zone               = "${local.zone}"

  wpt_server_image   = "${module.wpt-server-submissions-image.identifier}"
  cert_renewer_image = "${module.cert-renewer-image.identifier}"

  # The "submissions" deployment requires significantly more disk space because
  # it creates a new git working directory of the WPT repository for every
  # qualifying submission.
  wpt_server_disk_size = 100
}

output "wpt-live-address" {
  value = "${module.wpt-live.address}"
}

output "wpt-submissions-address" {
  value = "${module.wpt-submissions.address}"
}
