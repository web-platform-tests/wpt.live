locals {
  region        = "us-central1"
  zone          = "us-central1-b"
  project_name  = "wptdashboard"
  host_name     = "wheresbob.org"
  alt_host_name = "thecolbert.report"
}

provider "google" {
  project = "${local.project_name}"
  region = "${local.region}"
  credentials = "${file("google-cloud-platform-credentials.json")}"
}

provider "google-beta" {
  project = "${local.project_name}"
  region = "${local.region}"
  credentials = "${file("google-cloud-platform-credentials.json")}"
}

resource "google_compute_network" "default" {
  name                    = "web-platform-tests-live-network"
  auto_create_subnetworks = "false"
}


module "wpt-server-image-identifier" {
  source = "./infrastructure/docker-image"
  url = "https://gcr.io/v2/wptdashboard/web-platform-tests-live-wpt-server/tags/list"
}

module "wpt-server-image" {
  source = "github.com/terraform-google-modules/terraform-google-container-vm"

  container = {
    image = "gcr.io/${local.project_name}/web-platform-tests-live-wpt-server@${module.wpt-server-image-identifier.identifier}"

    env = [
      {
        name  = "WPT_HOST"
        value = "${local.host_name}"
      },
      {
        name  = "WPT_ALT_HOST"
        value = "${local.alt_host_name}"
      },
      {
        name  = "WPT_BUCKET"
        value = "web-platform-tests-live-demo"
      }
    ]
  }

  restart_policy = "Always"
}

module "cert-renewer-image" {
  source = "github.com/terraform-google-modules/terraform-google-container-vm"

  container = {
    image = "gcr.io/${local.project_name}/web-platform-tests-live-cert-renewer"

    env = [
      {
        name  = "WPT_HOST"
        value = "${local.host_name}"
      },
      {
        name  = "WPT_ALT_HOST"
        value = "${local.alt_host_name}"
      },
      {
        name  = "WPT_BUCKET"
        value = "web-platform-tests-live-demo"
      }
    ]
  }

  restart_policy = "Always"
}

resource "google_compute_subnetwork" "default" {
  name                     = "web-platform-tests-live-subnetwork"
  ip_cidr_range            = "10.127.0.0/20"
  network                  = "${google_compute_network.default.self_link}"
  region                   = "${local.region}"
  private_ip_google_access = true
}

module "web-platform-tests-live" {
  source                         = "./infrastructure/web-platform-tests"
  providers {
    google-beta = "google-beta"
  }

  network_name                   = "${google_compute_network.default.name}"
  subnetwork_name                = "${google_compute_subnetwork.default.name}"
  bucket_name                    = "web-platform-tests-live-demo"
  host_zone_name                 = "web-platform-tests-host"
  alt_host_zone_name             = "web-platform-tests-alt-host"
  region                         = "${local.region}"
  zone                           = "${local.zone}"

  wpt_server_machine_image       = "${module.wpt-server-image.source_image}"
  wpt_server_instance_labels     = "${map(
    "${module.wpt-server-image.vm_container_label_key}",
    "${module.wpt-server-image.vm_container_label}"
  )}"
  wpt_server_instance_metadata   = "${map(
    "${module.wpt-server-image.metadata_key}",
    "${module.wpt-server-image.metadata_value}"
  )}"

  cert_renewer_machine_image     = "${module.cert-renewer-image.source_image}"
  cert_renewer_instance_labels   = "${map(
    "${module.cert-renewer-image.vm_container_label_key}",
    "${module.cert-renewer-image.vm_container_label}"
  )}"
  cert_renewer_instance_metadata = "${map(
    "${module.cert-renewer-image.metadata_key}",
    "${module.cert-renewer-image.metadata_value}"
  )}"
}

output "web-platform-tests-live-address" {
  value = "${module.web-platform-tests-live.address}"
}
