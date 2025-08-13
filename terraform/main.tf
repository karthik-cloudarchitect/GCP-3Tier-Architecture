# GCP 3-Tier Architecture Terraform Configuration
# This template creates a complete 3-tier architecture on GCP with:
# - Presentation Tier: Load Balancer
# - Application Tier: Managed Instance Group
# - Data Tier: Cloud SQL Database

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "sql_api" {
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "servicenetworking_api" {
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "secretmanager_api" {
  service = "secretmanager.googleapis.com"
}

# VPC Network
resource "google_compute_network" "main_vpc" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460

  depends_on = [google_project_service.compute_api]
}

# Public Subnet for Load Balancer and Web Tier
resource "google_compute_subnetwork" "public_subnet" {
  name          = "${var.project_name}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# Private Subnet for Application Tier
resource "google_compute_subnetwork" "private_subnet" {
  name          = "${var.project_name}-private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# Database Subnet for Cloud SQL
resource "google_compute_subnetwork" "db_subnet" {
  name          = "${var.project_name}-db-subnet"
  ip_cidr_range = var.db_subnet_cidr
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# Private IP allocation for Cloud SQL
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.project_name}-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main_vpc.id

  depends_on = [google_project_service.servicenetworking_api]
}

# Private connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}