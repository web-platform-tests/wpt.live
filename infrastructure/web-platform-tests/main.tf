locals {
  bucket_name = "${var.name}-certificates"

  update_policy = {
    type           = "PROACTIVE"
    minimal_action = "RESTART"
    # > maxUnavailable must be greater than 0 when minimal action is set to
    # > RESTART
    max_unavailable_fixed = 1
  }

}

module "wpt-server-container" {
  source  = "terraform-google-modules/container-vm/google"
  version = "3.0.0"

  container = {
    image = var.wpt_server_image
    env = [
      {
        name  = "WPT_HOST"
        value = var.host_name
      },
      {
        name  = "WPT_ALT_HOST"
        value = var.alt_host_name
      },
      {
        name  = "WPT_BUCKET"
        value = local.bucket_name
      },
    ]
  }

  restart_policy = "Always"
}

resource "google_storage_bucket" "certificates" {
  name     = local.bucket_name
  location = "US"
}
