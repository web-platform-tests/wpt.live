locals {
  region       = "us-central1"
  zone         = "us-central1-b"
  project_name = "wptdashboard"
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

module "wpt-server-submissions-image" {
  source   = "./infrastructure/docker-image"
  registry = "gcr.io"
  image    = "${local.project_name}/web-platform-tests-live-wpt-server-submissions"
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
  host_zone_name     = "web-platform-tests-tot-host"
  host_name          = "web-platform-tests.live"
  alt_host_zone_name = "web-platform-tests-tot-alt-host"
  alt_host_name      = "not-web-platform-tests.live"
  region             = "${local.region}"
  zone               = "${local.zone}"

  wpt_server_image   = "${module.wpt-server-tot-image.identifier}"
  cert_renewer_image = "${module.cert-renewer-image.identifier}"
}

module "web-platform-tests-submissions" {
  source = "./infrastructure/web-platform-tests"

  providers {
    google-beta = "google-beta"
  }

  name               = "web-platform-tests-submissions"
  network_name       = "${google_compute_network.default.name}"
  subnetwork_name    = "${google_compute_subnetwork.default.name}"
  host_zone_name     = "web-platform-tests-submissions-host"
  host_name          = "webplatformtests.org"
  alt_host_zone_name = "web-platform-tests-submissions-alt-host"
  alt_host_name      = "webplatformtests.com"
  region             = "${local.region}"
  zone               = "${local.zone}"

  wpt_server_image   = "${module.wpt-server-submissions-image.identifier}"
  cert_renewer_image = "${module.cert-renewer-image.identifier}"

  # The "submissions" deployment requires significantly more disk space because
  # it creates a new git working directory of the WPT repository for every
  # qualifying submission.
  wpt_server_disk_size = 100
}

output "web-platform-tests-live-address" {
  value = "${module.web-platform-tests-live.address}"
}

output "web-platform-tests-submissions-address" {
  value = "${module.web-platform-tests-submissions.address}"
}
