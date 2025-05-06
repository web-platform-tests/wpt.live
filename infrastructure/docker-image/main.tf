variable "registry" {
  description = "Host name of the Docker registry from which the image identifier should be retirieved"
  type        = string
}

variable "image" {
  description = "Name of the Docker image whose identifier should be retrieved"
  type        = string
}

output "identifier" {
  value = "${data.docker_image.image.repo_digest}"
}

data "docker_image" "image" {
  name = "${var.registry}/${var.image}:latest"
}
