# Compute Resources - Application Tier

# Create startup script for application servers
resource "google_storage_bucket" "startup_scripts" {
  name          = "${var.project_id}-${var.project_name}-startup-scripts"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

# Upload startup script to bucket
resource "google_storage_bucket_object" "startup_script" {
  name   = "startup.sh"
  bucket = google_storage_bucket.startup_scripts.name
  source = "${path.module}/scripts/startup.sh"
}

# Service account for compute instances
resource "google_service_account" "compute_service_account" {
  account_id   = "${var.project_name}-compute-sa"
  display_name = "Compute Service Account for ${var.project_name}"
}

# IAM bindings for service account
resource "google_project_iam_member" "compute_sa_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.compute_service_account.email}"
}

resource "google_project_iam_member" "compute_sa_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.compute_service_account.email}"
}

resource "google_project_iam_member" "compute_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.compute_service_account.email}"
}

resource "google_project_iam_member" "compute_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.compute_service_account.email}"
}

# Instance template
resource "google_compute_instance_template" "app_template" {
  name_prefix  = "${var.project_name}-template-"
  machine_type = var.machine_type
  region       = var.region

  tags = ["app-server", "ssh-access"]

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  network_interface {
    network    = google_compute_network.main_vpc.id
    subnetwork = google_compute_subnetwork.private_subnet.id

    # Remove external IP for security (instances will use NAT for outbound)
    # access_config {}
  }

  service_account {
    email  = google_service_account.compute_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script-url = "gs://${google_storage_bucket.startup_scripts.name}/startup.sh"
    app-port          = var.app_port
    db-connection     = google_sql_database_instance.main_instance.connection_name
    db-name           = google_sql_database.main_database.name
    db-user           = google_sql_user.main_user.name
    environment       = var.environment
  }

  metadata_startup_script = file("${path.module}/scripts/startup.sh")

  lifecycle {
    create_before_destroy = true
  }
}

# Managed instance group
resource "google_compute_instance_group_manager" "app_group" {
  name = "${var.project_name}-instance-group"
  zone = var.zone

  version {
    instance_template = google_compute_instance_template.app_template.id
    name              = "primary"
  }

  base_instance_name = "${var.project_name}-instance"
  target_size        = var.min_replicas

  named_port {
    name = "http"
    port = var.app_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app_health_check.id
    initial_delay_sec = 300
  }

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 3
    max_unavailable_fixed        = 0
  }
}

# Autoscaler
resource "google_compute_autoscaler" "app_autoscaler" {
  name   = "${var.project_name}-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.app_group.id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }

    load_balancing_utilization {
      target = 0.8
    }
  }
}

# NAT Gateway for outbound internet access from private instances
resource "google_compute_router" "nat_router" {
  name    = "${var.project_name}-nat-router"
  region  = var.region
  network = google_compute_network.main_vpc.id
}

resource "google_compute_router_nat" "nat_gateway" {
  name                               = "${var.project_name}-nat-gateway"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}