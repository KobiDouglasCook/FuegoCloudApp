# FuegoCloudApp Infrastructure

This project defines the infrastructure for the **FuegoCloudApp** using [Terraform](https://www.terraform.io/) on AWS.

## 🔧 Infrastructure Overview

The infrastructure provisions and configures the following AWS resources:

- **EC2 Instances**: Virtual servers for running application workloads.
- **S3 Bucket**: Used as a remote backend for Terraform state storage.
- **DynamoDB Table**: Provides state locking and consistency for Terraform.
- **RDS (PostgreSQL)**: Managed relational database for persistent data.
- **Route 53**: DNS service to route traffic to the application.
- **Application Load Balancer (ALB)**: Distributes traffic across multiple EC2 instances.
- **Security Groups**: Custom firewall rules to control network access.

## 📁 Project Structure

.
├── main.tf # Main Terraform configuration
├── variables.tf # Input variables for customization
├── terraform.tfvars # Variable values (not committed if sensitive)
├── outputs.tf # Outputs after provisioning
├── backend.tf # Remote backend config (S3 + DynamoDB)
└── modules/ # (optional) Any reusable infrastructure modules

