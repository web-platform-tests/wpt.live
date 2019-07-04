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

variable "bucket_name" {
  type = "string"
}

variable "host_zone_name" {
  type = "string"
  description = "The primary host to be used by the web-platform-tests server"
}

variable "alt_host_zone_name" {
  type        = "string"
  description = "The secondary host to be used by the web-platform-tests server"
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

variable "cert_renewer_instance_labels" {
  type = "map"
}

variable "cert_renewer_instance_metadata" {
  type = "map"
}
