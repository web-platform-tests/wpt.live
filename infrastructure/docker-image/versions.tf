
terraform {
  required_version = "~> 1.6.2"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  registry_auth {
    address     = var.registry
    config_file = pathexpand("~/.docker/config.json")
  }
}
