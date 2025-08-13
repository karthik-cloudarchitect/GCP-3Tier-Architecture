# Load Balancer Configuration - Presentation Tier

# Global IP address for the load balancer
resource "google_compute_global_address" "lb_ip" {
  name = "${var.project_name}-lb-ip"
}

# Health check for backend instances
resource "google_compute_health_check" "app_health_check" {
  name               = "${var.project_name}-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path = "/health"
    port         = var.app_port
  }
}

# Backend service
resource "google_compute_backend_service" "app_backend" {
  name                  = "${var.project_name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.app_health_check.id]

  backend {
    group           = google_compute_instance_group_manager.app_group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map
resource "google_compute_url_map" "app_url_map" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.app_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.app_backend.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.app_backend.id
    }
  }
}

# HTTP proxy
resource "google_compute_target_http_proxy" "app_proxy" {
  name    = "${var.project_name}-proxy"
  url_map = google_compute_url_map.app_url_map.id
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "app_forwarding_rule" {
  name       = "${var.project_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.app_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip.address
}

# HTTPS Configuration (Optional)
# SSL Certificate (self-managed)
resource "google_compute_managed_ssl_certificate" "app_ssl_cert" {
  name = "${var.project_name}-ssl-cert"

  managed {
    domains = ["${var.project_name}.example.com"]
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "app_https_proxy" {
  name             = "${var.project_name}-https-proxy"
  url_map          = google_compute_url_map.app_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app_ssl_cert.id]
}

# HTTPS forwarding rule
resource "google_compute_global_forwarding_rule" "app_https_forwarding_rule" {
  name       = "${var.project_name}-https-forwarding-rule"
  target     = google_compute_target_https_proxy.app_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address
}