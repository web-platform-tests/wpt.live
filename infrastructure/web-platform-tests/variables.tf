variable "region" {
  type = "string"
}

variable "zone" {
  type = "string"
}

variable "network_name" {
  type = "string"
}

variable "subnetwork_name" {
  type = "string"
}

variable "wpt_server_machine_image" {
  type = "string"
}

variable "wpt_server_instance_labels" {
  type = "map"
}

variable "wpt_server_instance_metadata" {
  type = "map"
}

variable "cert_renewer_machine_image" {
  type = "string"
}
