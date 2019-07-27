variable "url" {
  type = "string"
}

output "identifier" {
  value = "${null_resource.image.id}"
}

resource "null_resource" "image" {
  provisioner "local-exec" {
    command = "python3 ${path.module}/latest-image.py ${var.url}"
  }
}
