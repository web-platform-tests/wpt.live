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


resource "google_service_account" "wpt_live_sa" {
  account_id   = "${var.name}-sa"
  display_name = "WPT Live Node Service Account"
}

resource "google_project_iam_member" "sa_logging" {
  project = data.google_project.project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wpt_live_sa.email}"
}

resource "google_storage_bucket_iam_member" "sa_storage" {
  bucket = google_storage_bucket.certificates.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.wpt_live_sa.email}"
}

resource "google_project_iam_member" "sa_artifactregistry" {
  project = data.google_project.project.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.wpt_live_sa.email}"
}

resource "google_compute_region_instance_group_manager" "wpt_server_cloud_init" {
  name                      = "${var.name}-instance-group-cloud-init"
  base_instance_name        = "${var.name}-cloud-init"
  region                    = var.region
  distribution_policy_zones = [var.zone]

  version {
    instance_template = google_compute_instance_template.wpt_server_cloud_init.id
  }

  update_policy {
    minimal_action       = local.update_policy.minimal_action
    type                 = local.update_policy.type
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
    initial_delay_sec = 180
  }
}

resource "google_compute_instance_template" "wpt_server_cloud_init" {
  name_prefix = "cloud-init-"

  machine_type = "e2-medium"

  network_interface {
    network    = var.network_name
    subnetwork = var.subnetwork_name
    access_config {
      network_tier = "PREMIUM"
    }
  }

  can_ip_forward = false

  disk {
    auto_delete  = true
    boot         = true
    source_image = data.google_compute_image.cos.self_link
    type         = "PERSISTENT"
    disk_type    = "pd-ssd"
    disk_size_gb = var.wpt_server_disk_size
    mode         = "READ_WRITE"
  }

  service_account {
    email  = google_service_account.wpt_live_sa.email
    scopes = ["cloud-platform"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  metadata = {
    "user-data" = templatefile("${path.module}/../../src/cloud-init.yaml", {
      WPT_HOST         = var.host_name
      WPT_ALT_HOST     = var.alt_host_name
      WPT_BUCKET       = local.bucket_name
      WPT_SERVER_IMAGE = var.wpt_server_image
    })
    "google-logging-enabled" = "true"
  }

  lifecycle {
    create_before_destroy = true
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
}



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


########################################
# Cert Renewers
########################################

resource "google_cloud_run_v2_job" "cert_renewers" {
  name         = "${var.name}-cert-renewers"
  location     = var.region

  template {
    template {
      containers {
        image = var.cert_renewer_image
        env {
          name  = "WPT_HOST"
          value = var.host_name
        }
        env {
          name  = "WPT_ALT_HOST"
          value = var.alt_host_name
        }
        env {
          name  = "WPT_BUCKET"
          value = local.bucket_name
        }
      }
    }
  }
}

data "google_project" "project" {
}

resource "google_cloud_scheduler_job" "cert_renewer_schedule" {
  provider         = google
  name             = "${var.name}-cert-renewer-schedule"
  description      = "cert renewal schedule job"
  schedule         = "0 0 * * *"
  attempt_deadline = "320s"
  region           = "us-central1"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "https://${google_cloud_run_v2_job.cert_renewers.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.project.number}/jobs/${google_cloud_run_v2_job.cert_renewers.name}:run"
    oauth_token {
      service_account_email = var.service_account_email
    }
  }
}
