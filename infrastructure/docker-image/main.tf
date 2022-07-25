variable "registry" {
  description = "Host name of the Docker registry from which the image identifier should be retirieved"
  type        = string
}

variable "image" {
  description = "Name of the Docker image whose identifier should be retrieved"
  type        = string
}

output "identifier" {
  value = "${var.registry}/${var.image}@${data.external.image.result.identifier}"
}

data "external" "image" {
  program = [
    "python3",
    "${path.module}/latest-image.py",
    "--registry",
    var.registry,
    "--image",
    var.image,
  ]
}
