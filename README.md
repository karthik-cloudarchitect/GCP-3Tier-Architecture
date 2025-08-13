# GCP 3-Tier Architecture

This repository contains a complete 3-tier architecture implementation on Google Cloud Platform (GCP) using Terraform for infrastructure as code and a Node.js test application.

## Architecture Overview

This implementation follows the classic 3-tier architecture pattern:

### 1. Presentation Tier (Web/Load Balancer)
- **Global HTTP(S) Load Balancer** - Distributes incoming requests
- **SSL Termination** - Handles HTTPS traffic
- **Global IP Address** - Single entry point for the application

### 2. Application Tier (Compute)
- **Managed Instance Group** - Auto-scaling application servers
- **Instance Templates** - Consistent server configuration
- **Health Checks** - Monitors application health
- **Auto Scaling** - Scales based on CPU and load metrics
- **Private Subnet** - Secure internal communication

### 3. Data Tier (Database)
- **Cloud SQL PostgreSQL** - Managed database service
- **Private IP** - Secure database access
- **Automated Backups** - Point-in-time recovery
- **Read Replica** - Performance optimization
- **Secret Manager** - Secure credential storage

## Project Structure

```
GCP-3Tier-Architecture/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   ├── versions.tf           # Provider requirements
│   ├── firewall.tf           # Firewall rules
│   ├── load_balancer.tf      # Load balancer configuration
│   ├── compute.tf            # Compute resources
│   ├── database.tf           # Database configuration
│   ├── scripts/
│   │   └── startup.sh        # Instance startup script
│   └── terraform.tfvars.example # Example variables file
├── app/                      # Test Application
│   ├── server.js             # Node.js application
│   ├── package.json          # Dependencies
│   ├── Dockerfile            # Container configuration
│   ├── healthcheck.js        # Health check script
│   └── env.example           # Environment variables example
└── README.md                 # This file
```

## Prerequisites

1. **Google Cloud Platform Account**
   - Active GCP project with billing enabled
   - Required APIs enabled (automatically enabled by Terraform)

2. **Local Development Tools**
   - [Terraform](https://www.terraform.io/downloads.html) >= 1.0
   - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
   - [Node.js](https://nodejs.org/) >= 18.x (for local testing)
   - [Docker](https://docs.docker.com/get-docker/) (optional)

3. **Authentication**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd GCP-3Tier-Architecture
```

### 2. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your project details:
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Test the Application

After deployment, get the load balancer IP:
```bash
terraform output load_balancer_ip
```

Test the endpoints:
```bash
# Health check
curl http://<LOAD_BALANCER_IP>/health

# API status
curl http://<LOAD_BALANCER_IP>/api/status

# List users
curl http://<LOAD_BALANCER_IP>/api/users

# Create a user
curl -X POST http://<LOAD_BALANCER_IP>/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

## Application Details

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information and available endpoints |
| GET | `/health` | Health check (for load balancer) |
| GET | `/ready` | Readiness check (database connectivity) |
| GET | `/api/status` | Detailed application and database status |
| GET | `/api/users` | List all users |
| POST | `/api/users` | Create a new user |
| GET | `/api/users/:id` | Get user by ID |

### Local Development

1. **Setup Database** (Docker example):
   ```bash
   docker run --name postgres-local \
     -e POSTGRES_DB=appdb \
     -e POSTGRES_USER=appuser \
     -e POSTGRES_PASSWORD=password \
     -p 5432:5432 \
     -d postgres:15
   ```

2. **Run Application**:
   ```bash
   cd app
   npm install
   
   # Copy environment file
   cp env.example .env
   # Edit .env with your database settings
   
   npm run dev
   ```

## Configuration

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP Project ID | Required |
| `project_name` | Resource name prefix | `three-tier-app` |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |
| `machine_type` | VM instance type | `e2-medium` |
| `min_replicas` | Minimum instances | `2` |
| `max_replicas` | Maximum instances | `10` |
| `app_port` | Application port | `8080` |

### Customization

- **Scaling**: Modify `min_replicas` and `max_replicas` in variables
- **Instance Size**: Change `machine_type` for different VM sizes
- **Database**: Adjust database tier in `database.tf`
- **Security**: Review firewall rules in `firewall.tf`

## Security Features

- **Private Subnets**: Application servers in private network
- **NAT Gateway**: Secure outbound internet access
- **Firewall Rules**: Restrictive network access controls
- **Service Accounts**: Minimal privilege principles
- **Secret Manager**: Secure credential storage
- **SSL/TLS**: HTTPS encryption support
- **Health Checks**: Automatic unhealthy instance replacement

## Monitoring and Logging

- **Cloud Logging**: Application and system logs
- **Cloud Monitoring**: Infrastructure metrics
- **Health Checks**: Application availability monitoring
- **Auto Scaling**: Performance-based scaling

## Production Considerations

1. **State Management**: Use remote state storage
   ```hcl
   backend "gcs" {
     bucket = "your-terraform-state-bucket"
     prefix = "terraform/state"
   }
   ```

2. **SSL Certificates**: Configure your domain in `load_balancer.tf`
3. **Database Security**: Enable SSL and configure authorized networks
4. **Backup Strategy**: Configure backup retention policies
5. **Monitoring**: Set up alerting and dashboards
6. **CI/CD**: Implement automated deployment pipelines

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will permanently delete all resources and data.

## Troubleshooting

### Common Issues

1. **API Not Enabled**: Ensure all required GCP APIs are enabled
2. **Permissions**: Verify service account has necessary permissions
3. **Quotas**: Check GCP quotas for compute instances and SQL
4. **Networking**: Verify firewall rules and subnet configurations

### Debugging

- Check instance logs: `gcloud compute instances get-serial-port-output`
- Review load balancer status: Cloud Console > Network Services > Load Balancing
- Monitor database: Cloud Console > SQL > Instance details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Create an issue in this repository
- Review GCP documentation
- Check Terraform provider documentation
