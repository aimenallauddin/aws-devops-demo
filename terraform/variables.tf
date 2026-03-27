# ── Variables ─────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for all resources"
  type        = string
  default     = "aws-devops-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"   # Gives us 65,536 IP addresses
}
variable "github_repository" {
  description = "The GitHub repository in 'username/repo-name' format"
  type        = string
  default     = "aimenallauddin/aws-devops-demo" 
}

variable "github_connection_arn" {
  description = "The ARN of the AWS CodeStar Connection to GitHub"
  type        = string
}