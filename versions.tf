
terraform {
  backend "gcs" {
    bucket = "wpt-live-app-tfstate"
    prefix = "terraform/state"
  }
  required_version = "~> 1.6.2"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
