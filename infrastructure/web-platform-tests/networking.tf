resource "google_compute_address" "web-platform-tests-live-address" {
  name = "${var.name}-address"
}

data "google_dns_managed_zone" "host" {
  name = var.host_zone_name
}

resource "google_dns_record_set" "host_bare" {
  name = data.google_dns_managed_zone.host.dns_name
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.host.name

  rrdatas = [google_compute_address.web-platform-tests-live-address.address]
}

resource "google_dns_record_set" "host_subdomains" {
  name = "*.${data.google_dns_managed_zone.host.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.host.name

  rrdatas = [data.google_dns_managed_zone.host.dns_name]
}

resource "google_dns_record_set" "host_nonexistent_subdomains" {
  name = "nonexistent.${data.google_dns_managed_zone.host.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.host.name

  rrdatas = ["0.0.0.0"]
}

data "google_dns_managed_zone" "alt_host" {
  name = var.alt_host_zone_name
}

resource "google_dns_record_set" "alt_host_bare" {
  name = data.google_dns_managed_zone.alt_host.dns_name
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.alt_host.name

  rrdatas = [google_compute_address.web-platform-tests-live-address.address]
}

resource "google_dns_record_set" "alt_host_subdomains" {
  name = "*.${data.google_dns_managed_zone.alt_host.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.alt_host.name

  rrdatas = [data.google_dns_managed_zone.alt_host.dns_name]
}

resource "google_dns_record_set" "alt_host_nonexistent_subdomains" {
  name = "nonexistent.${data.google_dns_managed_zone.alt_host.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.alt_host.name

  rrdatas = ["0.0.0.0"]
}
