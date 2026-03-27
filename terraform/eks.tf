# ─────────────────────────────────────────────────────────────
# EKS (Elastic Kubernetes Service)
# AWS-managed Kubernetes control plane + worker nodes.
# ─────────────────────────────────────────────────────────────

# ── IAM Role for the EKS Control Plane ───────────────────────


resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ── EKS Cluster ───────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    # Spread across both public and private subnets
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true    # kubectl works from inside the VPC
    endpoint_public_access  = true    # kubectl also works from my laptop
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# ── IAM Role for Worker Nodes ─────────────────────────────────
# EC2 instances (nodes) need permissions to join the cluster
# and pull images from ECR

resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Allows nodes to register with the EKS cluster
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

# Allows the CNI plugin to manage pod networking
resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

# Allows nodes to pull Docker images from ECR
resource "aws_iam_role_policy_attachment" "eks_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ── Managed Node Group ────────────────────────────────────────
# The actual EC2 instances that run our pods.

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id   # Nodes in private subnets (no public IP)
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2   
    min_size     = 1   
    max_size     = 4 
  }

  update_config {
    max_unavailable = 1  
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_ecr,
  ]
}

# ── ECR Repository ────────────────────────────────────────────
# Private Docker image registry — stores the images built by CI/CD

resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"   # Allows overwriting the 'latest' tag

  # Automatically scan images for known vulnerabilities on push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = var.project_name }
}

# Lifecycle policy: automatically delete old images to save storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
