terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 — run scripts/bootstrap.sh first
  backend "s3" {
    bucket         = "aws-devops-demo-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}


output "ecr_repository_url" {
  description = "ECR URL to push Docker images to"
  value       = aws_ecr_repository.app.repository_url
}

output "eks_cluster_name" {
  description = "EKS cluster name — use with: aws eks update-kubeconfig --name <value>"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eks_cluster.main.endpoint
}
