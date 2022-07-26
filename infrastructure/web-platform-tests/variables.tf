variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "name" {
  type = string
}

variable "network_name" {
  type = string
}

variable "subnetwork_name" {
  type = string
}

variable "host_zone_name" {
  type        = string
  description = "The primary host to be used by the web-platform-tests server"
}

variable "host_name" {
  type = string
}

variable "alt_host_zone_name" {
  type        = string
  description = "The secondary host to be used by the web-platform-tests server"
}

variable "alt_host_name" {
  type = string
}

variable "wpt_server_image" {
  type        = string
  description = "The address of a Docker image that runs the web-platform-tests server"
}

variable "cert_renewer_image" {
  type        = string
  description = "The address of of a Docker image that renews TLS certificates for the system"
}

variable "wpt_server_disk_size" {
  description = "The size of the disk in gigabytes. If not specified, it will inherit the size of its base image."
  default     = 0
}

variable "wpt_server_ports" {
  type = list(object({
    name = string
    port = number
  }))
  description = "Mapping of name to port. Ports are used for the wpt server."
  default = [
    {
      name = "http-primary",
      port = 80
    },
    {
      name = "http-secondary",
      port = 8000
    },
    {
      name = "https",
      port = 443
    },
    {
      name = "http2",
      port = 8001
    },
    {
      name = "websocket",
      port = 8002
    },
    {
      name = "websocket-secure",
      port = 8003
    },
    {
      name = "https-secondary",
      port = 8443
    },
  ]
}


variable "cert_renewer_ports" {
  type = list(object({
    name = string
    port = number
  }))
  description = "Mapping of name to port. Ports are used for the cert renewer."
  default = [
    {
      name = "http",
      port = 8004
    }
  ]
}

variable "cos_image_name" {
  description = "Name of specific COS image. Temporary variable. Will remove here and in main.tf once ready to upgrade. More info: https://github.com/terraform-google-modules/terraform-google-container-vm/blob/5e69eafaaaa8302c5732799e32d1da5c17b7b285/variables.tf#L46"
  type        = string
  default     = "cos-stable-85-13310-1209-17"
}