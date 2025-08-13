# Firewall Rules for 3-Tier Architecture

# Allow HTTP and HTTPS traffic to Load Balancer
resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.project_name}-allow-http-https"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# Allow internal communication between subnets
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_name}-allow-internal"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.public_subnet_cidr,
    var.private_subnet_cidr,
    var.db_subnet_cidr
  ]
}

# Allow SSH access for management
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-allow-ssh"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-access"]
}

# Allow health check traffic
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.project_name}-allow-health-check"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = [var.app_port]
  }

  # Health check source ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  
  target_tags = ["app-server"]
}

# Allow application port traffic from load balancer
resource "google_compute_firewall" "allow_app_port" {
  name    = "${var.project_name}-allow-app-port"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = [var.app_port]
  }

  source_ranges = [var.public_subnet_cidr]
  target_tags   = ["app-server"]
}