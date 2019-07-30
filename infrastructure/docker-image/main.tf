variable "registry" {
  type = "string"
}

variable "image" {
  type = "string"
}

output "identifier" {
  value = "${var.registry}/${var.image}@${data.external.image.result.identifier}"
}

data "external" "image" {
  program = [
    "python3",
    "${path.module}/latest-image.py",
    "--registry", "${var.registry}",
    "--image", "${var.image}"
  ]
}
