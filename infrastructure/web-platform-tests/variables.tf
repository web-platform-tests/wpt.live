variable "region" {
  type = "string"
}

variable "zone" {
  type = "string"
}

variable "name" {
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
  type        = "string"
  description = "The primary host to be used by the web-platform-tests server"
}

variable "host_name" {
  type = "string"
}

variable "alt_host_zone_name" {
  type        = "string"
  description = "The secondary host to be used by the web-platform-tests server"
}

variable "alt_host_name" {
  type = "string"
}

variable "wpt_server_image" {
  type = "string"
}

variable "cert_renewer_image" {
  type = "string"
}

variable "wpt_server_disk_size" {
  description = "The size of the disk in gigabytes. If not specified, it will inherit the size of its base image."
  default     = 0
}
