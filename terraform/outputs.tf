# Outputs for GCP 3-Tier Architecture

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = "http://${google_compute_global_address.lb_ip.address}"
}

output "load_balancer_https_url" {
  description = "HTTPS URL of the load balancer"
  value       = "https://${google_compute_global_address.lb_ip.address}"
}

output "database_connection_name" {
  description = "Connection name for the Cloud SQL instance"
  value       = google_sql_database_instance.main_instance.connection_name
  sensitive   = false
}

output "database_private_ip" {
  description = "Private IP address of the database"
  value       = google_sql_database_instance.main_instance.private_ip_address
}

output "database_name" {
  description = "Name of the database"
  value       = google_sql_database.main_database.name
}

output "database_user" {
  description = "Database username"
  value       = google_sql_user.main_user.name
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main_vpc.name
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = google_compute_subnetwork.public_subnet.ip_cidr_range
}

output "private_subnet_cidr" {
  description = "CIDR block of the private subnet"
  value       = google_compute_subnetwork.private_subnet.ip_cidr_range
}

output "instance_group_name" {
  description = "Name of the managed instance group"
  value       = google_compute_instance_group_manager.app_group.name
}

output "instance_template_name" {
  description = "Name of the instance template"
  value       = google_compute_instance_template.app_template.name
}

output "service_account_email" {
  description = "Email of the compute service account"
  value       = google_service_account.compute_service_account.email
}

output "nat_gateway_name" {
  description = "Name of the NAT gateway"
  value       = google_compute_router_nat.nat_gateway.name
}

output "secret_manager_secret_name" {
  description = "Name of the Secret Manager secret for database password"
  value       = google_secret_manager_secret.db_password.secret_id
}