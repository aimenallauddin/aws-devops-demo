# ─────────────────────────────────────────────────────────────
# TERRAFORM CONFIGURATION
# Defines the required Terraform version, AWS provider,
# and remote state backend.
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }


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

  # These tags are automatically applied to every resource Terraform creates
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# ── Outputs ───────────────────────────────────────────────────

output "ecr_repository_url" {
  description = "ECR URL — set this as the ECR_REGISTRY GitHub secret"
  value       = aws_ecr_repository.app.repository_url
}

output "eks_cluster_name" {
  description = "Run: aws eks update-kubeconfig --name <value> to connect kubectl"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}
output "codepipeline_name" {
  description = "The name of the pipeline created"
  value       = aws_codepipeline.main.name
}