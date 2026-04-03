locals {
  bucket_name = "${var.name}-certificates"

  update_policy = {
    type           = "PROACTIVE"
    minimal_action = "REPLACE"
    # > maxUnavailable must be greater than 0 when minimal action is set to
    # > RESTART
    max_unavailable_fixed = 1
  }

}


resource "google_storage_bucket" "certificates" {
  name                        = local.bucket_name
  location                    = "US"
  uniform_bucket_level_access = true
}

data "google_compute_image" "cos" {
  family  = "cos-stable"
  project = "cos-cloud"
}
