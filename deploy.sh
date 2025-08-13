#!/bin/bash

# GCP 3-Tier Architecture Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command_exists gcloud; then
        print_error "Google Cloud SDK (gcloud) is not installed. Please install it first."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null 2>&1; then
        print_error "Not authenticated with Google Cloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    print_success "All prerequisites satisfied!"
}

# Function to set up project
setup_project() {
    print_status "Setting up GCP project..."
    
    # Get current project
    current_project=$(gcloud config get-value project 2>/dev/null || echo "")
    
    if [ -z "$current_project" ]; then
        print_error "No active GCP project set. Please run 'gcloud config set project YOUR_PROJECT_ID'"
        exit 1
    fi
    
    print_status "Using project: $current_project"
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_status "Creating terraform.tfvars file..."
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        
        # Update project_id in terraform.tfvars
        sed -i "s/your-gcp-project-id/$current_project/g" terraform/terraform.tfvars
        
        print_warning "Please review and update terraform/terraform.tfvars with your desired configuration"
        print_warning "Press Enter to continue after reviewing the file, or Ctrl+C to exit"
        read -r
    fi
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    cd terraform
    terraform init
    cd ..
    print_success "Terraform initialized successfully!"
}

# Function to plan deployment
plan_deployment() {
    print_status "Planning Terraform deployment..."
    cd terraform
    terraform plan -out=tfplan
    cd ..
    print_success "Terraform plan created successfully!"
    
    print_warning "Review the above plan carefully. Press Enter to continue with deployment, or Ctrl+C to exit"
    read -r
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    cd terraform
    terraform apply tfplan
    cd ..
    print_success "Infrastructure deployed successfully!"
}

# Function to get deployment information
get_deployment_info() {
    print_status "Getting deployment information..."
    cd terraform
    
    echo ""
    print_success "Deployment completed! Here are the details:"
    echo ""
    
    echo "Load Balancer IP: $(terraform output -raw load_balancer_ip)"
    echo "Load Balancer URL: $(terraform output -raw load_balancer_url)"
    echo "Database Connection: $(terraform output -raw database_connection_name)"
    echo ""
    
    print_status "Testing endpoints (this may take a few minutes for instances to be ready)..."
    LB_IP=$(terraform output -raw load_balancer_ip)
    
    # Wait for instances to be ready
    print_status "Waiting for application to be ready..."
    for i in {1..30}; do
        if curl -s "http://$LB_IP/health" >/dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 10
    done
    echo ""
    
    echo "Testing endpoints:"
    echo "Health check: curl http://$LB_IP/health"
    echo "API status: curl http://$LB_IP/api/status"
    echo "List users: curl http://$LB_IP/api/users"
    
    cd ..
}

# Function to clean up deployment
cleanup_deployment() {
    print_warning "This will destroy all resources. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_status "Destroying infrastructure..."
        cd terraform
        terraform destroy -auto-approve
        cd ..
        print_success "Infrastructure destroyed successfully!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Main script
main() {
    echo "=================================="
    echo "  GCP 3-Tier Architecture Setup  "
    echo "=================================="
    echo ""
    
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            setup_project
            init_terraform
            plan_deployment
            deploy_infrastructure
            get_deployment_info
            ;;
        "plan")
            check_prerequisites
            init_terraform
            cd terraform && terraform plan && cd ..
            ;;
        "destroy")
            cleanup_deployment
            ;;
        "info")
            cd terraform && terraform output && cd ..
            ;;
        "help")
            echo "Usage: $0 [deploy|plan|destroy|info|help]"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the complete infrastructure (default)"
            echo "  plan     - Show the deployment plan without applying"
            echo "  destroy  - Destroy all resources"
            echo "  info     - Show deployment information"
            echo "  help     - Show this help message"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Run '$0 help' for available commands"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"