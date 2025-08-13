# Database Configuration - Data Tier

# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Cloud SQL Instance
resource "google_sql_database_instance" "main_instance" {
  name             = "${var.project_name}-${var.db_instance_name}"
  database_version = "POSTGRES_15"
  region           = var.region

  deletion_protection = false

  settings {
    tier                  = "db-f1-micro"
    activation_policy     = "ALWAYS"
    availability_type     = "ZONAL"
    disk_autoresize       = true
    disk_autoresize_limit = 100
    disk_size             = 20
    disk_type             = "PD_SSD"

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      location                       = var.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.main_vpc.id
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = false
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]
}

# Database
resource "google_sql_database" "main_database" {
  name     = var.db_name
  instance = google_sql_database_instance.main_instance.name
}

# Database user
resource "google_sql_user" "main_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main_instance.name
  password = random_password.db_password.result
}

# Store database password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_name}-db-password"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# IAM binding for compute instances to access secret
resource "google_secret_manager_secret_iam_member" "compute_secret_accessor" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.compute_service_account.email}"
}

# Read replica (optional for production workloads)
resource "google_sql_database_instance" "read_replica" {
  name                 = "${var.project_name}-${var.db_instance_name}-replica"
  database_version     = "POSTGRES_15"
  region               = var.region
  master_instance_name = google_sql_database_instance.main_instance.name

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_autoresize   = true
    disk_size         = 20
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.main_vpc.id
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = false
    }
  }
}