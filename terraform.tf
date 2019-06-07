
variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-b"
}

variable "network_name" {
  default = "tf-lb-basic"
}

provider "google" {
  project = "wptdashboard"
  region = "${var.region}"
  credentials = "${file("google-cloud-platform-credentials.json")}"
}

provider "google-beta" {
  project = "wptdashboard"
  region = "${var.region}"
  credentials = "${file("google-cloud-platform-credentials.json")}"
}

resource "google_compute_network" "default" {
  name                    = "${var.network_name}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "default" {
  name                     = "${var.network_name}"
  ip_cidr_range            = "10.127.0.0/20"
  network                  = "${google_compute_network.default.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = true
}

data "template_file" "group1-startup-script" {
  template = "${file("${format("%s/gceme.sh.tpl", path.module)}")}"

  vars {
    ALT_PORT = ""
  }
}

data "template_file" "group2-startup-script" {
  template = "${file("${format("%s/gceme.sh.tpl", path.module)}")}"

  vars {
    ALT_PORT = "8001"
  }
}

module "mig1" {
  # https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group/pull/39
  source            = "github.com/dcaba/terraform-google-managed-instance-group"
  providers {
    google-beta = "google-beta"
  }
  version           = "1.1.13"
  region            = "${var.region}"
  zone              = "${var.zone}"
  name              = "${var.network_name}-group1"
  size              = 2
  service_port      = 80
  service_port_name = "http"
  http_health_check = false
  target_pools      = ["${module.wpt-servers.target_pool}"]
  target_tags       = ["allow-service1"]
  startup_script    = "${data.template_file.group1-startup-script.rendered}"
  network           = "${google_compute_subnetwork.default.name}"
  subnetwork        = "${google_compute_subnetwork.default.name}"
}

module "mig2" {
  # https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group/pull/39
  source            = "github.com/dcaba/terraform-google-managed-instance-group"
  providers {
    google-beta = "google-beta"
  }
  region            = "${var.region}"
  zone              = "${var.zone}"
  name              = "${var.network_name}-group2"
  size              = 1
  service_port      = 8001
  service_port_name = "http"
  http_health_check = false
  target_pools      = ["${module.tls-certificate-renewer.target_pool}"]
  target_tags       = ["allow-service1"]
  startup_script    = "${data.template_file.group1-startup-script.rendered}"
  network           = "${google_compute_subnetwork.default.name}"
  subnetwork        = "${google_compute_subnetwork.default.name}"
}

resource "google_compute_address" "web-platform-tests-live-address" {
  name = "web-platform-tests-live-address"
}

module "wpt-servers" {
  source       = "./load-balancer"
  region       = "${var.region}"
  name         = "${var.network_name}-wpt"
  service_port = "${module.mig1.service_port}"
  target_tags  = ["${module.mig1.target_tags}"]
  network      = "${google_compute_subnetwork.default.name}"
  ip_address   = "${google_compute_address.web-platform-tests-live-address.address}"
  session_affinity = "CLIENT_IP_PROTO"
}

module "tls-certificate-renewer" {
  source       = "./load-balancer"
  region       = "${var.region}"
  name         = "${var.network_name}-tls"
  service_port = "${module.mig2.service_port}"
  target_tags  = ["${module.mig2.target_tags}"]
  network      = "${google_compute_subnetwork.default.name}"
  ip_address   = "${google_compute_address.web-platform-tests-live-address.address}"
  session_affinity = "CLIENT_IP_PROTO"
}

output "load-balancer-ip" {
  value = "${google_compute_address.web-platform-tests-live-address.address}"
}
