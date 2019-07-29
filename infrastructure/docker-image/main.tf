variable "url" {
  type = "string"
}

output "identifier" {
  value = "${data.external.image.result.identifier}"
}

data "external" "image" {
  program = ["python3", "${path.module}/latest-image.py", "${var.url}"]
}
