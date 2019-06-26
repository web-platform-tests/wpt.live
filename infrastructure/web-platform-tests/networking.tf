resource "google_compute_address" "web-platform-tests-live-address" {
  name = "web-platform-tests-live-address"
}

resource "google_dns_managed_zone" "host" {
  name = "web-platform-tests-host"
  dns_name = "${var.host_name}."
  description = "Primary host used by the web-platform-tests server"
}

resource "google_dns_record_set" "host_bare" {
  name = "${google_dns_managed_zone.host.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.host.name}"

  rrdatas = ["${google_compute_address.web-platform-tests-live-address.address}"]
}

resource "google_dns_record_set" "host_subdomains" {
  name = "*.${google_dns_managed_zone.host.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.host.name}"

  rrdatas = ["${google_dns_managed_zone.host.dns_name}"]
}

resource "google_dns_record_set" "host_nonexistent_subdomains" {
  name = "nonexistent.${google_dns_managed_zone.host.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.host.name}"

  rrdatas = ["0.0.0.0"]
}

resource "google_dns_managed_zone" "alt_host" {
  name = "web-platform-tests-alt-host"
  dns_name = "${var.alt_host_name}."
  description = "Secondary host used by the web-platform-tests server"
}

resource "google_dns_record_set" "alt_host_bare" {
  name = "${google_dns_managed_zone.alt_host.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.alt_host.name}"

  rrdatas = ["${google_compute_address.web-platform-tests-live-address.address}"]
}

resource "google_dns_record_set" "alt_host_subdomains" {
  name = "*.${google_dns_managed_zone.alt_host.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.alt_host.name}"

  rrdatas = ["${google_dns_managed_zone.alt_host.dns_name}"]
}

resource "google_dns_record_set" "alt_host_nonexistent_subdomains" {
  name = "nonexistent.${google_dns_managed_zone.alt_host.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.alt_host.name}"

  rrdatas = ["0.0.0.0"]
}
