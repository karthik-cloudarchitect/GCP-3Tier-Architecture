# Terraform version constraints and provider requirements

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  # Uncomment the following block to use remote state storage
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "terraform/state"
  # }
}