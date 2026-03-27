
# 🚀 AWS Enterprise DevOps: Automated EKS Pipeline
**Infrastructure-as-Code (Terraform) • AWS CodePipeline • Kubernetes (EKS) • Node.js**

An enterprise-grade DevOps ecosystem demonstrating a fully automated, AWS-native CI/CD lifecycle. This project replaces third-party CI tools with **AWS CodePipeline** and **CodeBuild**, ensuring a secure, internalized build process within the AWS backbone.

---

## 🏗️ Technical Architecture

| Layer | Technology | Engineering Choice |
| :--- | :--- | :--- |
| **Cloud** | AWS (EKS, ECR, VPC, IAM) | Multi-AZ High Availability |
| **IaC** | Terraform (v1.7+) | Modular, S3 Remote State + DynamoDB Locking |
| **CI/CD** | AWS CodePipeline | Native AWS integration; reduced secret exposure |
| **Build** | AWS CodeBuild | Serverless Docker builds via `buildspec.yml` |
| **Orchestration** | Kubernetes (EKS v1.29) | Managed Control Plane with Private Worker Nodes |
| **Container** | Docker (Alpine) | Multi-stage build, non-root user, minimal footprint |

---

## 🛤️ CI/CD Strategy: The "Source-to-Registry" Flow

This project utilizes a **Push-to-Deploy** model. Every merge to the `main` branch triggers the native AWS Pipeline:

1.  **Source:** AWS CodeStar Connection monitors GitHub for changes.
2.  **Build:** CodeBuild pulls the source, builds the Docker image, and tags it with a **Git Short SHA** for immutable traceability.
3.  **Security Scan:** Automated **ECR Scan on Push** checks for CVEs before the image is finalized.
4.  **Artifact Store:** Build logs and deployment metadata are encrypted and stored in an S3 Artifact bucket.

---

## 🛠️ Infrastructure Design

Provisioned via modular Terraform. Running `terraform apply` orchestrates:

* **Networking (`vpc.tf`):** Custom VPC with Public/Private subnet topology. EKS Nodes live in **Private Subnets** for security, reaching the internet via a **NAT Gateway**.
* **Compute (`eks.tf`):** Managed Node Group using `t3.medium` instances with an **Auto-Scaling Group (ASG)** (1–4 nodes).
* **Pipeline (`pipeline.tf`):** Full CI/CD stack including CodePipeline, S3 Artifact store, and IAM roles following the **Principle of Least Privilege**.
* **Storage (`eks.tf`):** Private ECR Repository with a **Lifecycle Policy** to expire images older than 10 versions for cost optimization.

```
terraform/
├── main.tf      # State Backend (S3/DynamoDB), Providers, Outputs
├── vpc.tf       # Networking & Routing Logic
├── eks.tf       # EKS Cluster, Node Groups, & ECR
├── pipeline.tf  # AWS CodePipeline & CodeBuild resources
└── variables.tf # Input parameters for environment reusability
```

---
## 🔐 Security & Engineering Standards
1. **State Locking:** Uses a DynamoDB table to prevent concurrent Terraform runs and state corruption.

2. **Pod Security:** Deployment uses securityContext to run as a non-root user (UID 1001).

3. **Health Strategy:** Implemented liveness and readiness probes to ensure high availability.

4. **Resource Management:** CPU/Memory limits defined to prevent "noisy neighbor" issues in the cluster.

5. **AWS Native CI:** Build and deploy traffic stays within the AWS network, significantly reducing the surface area for credential leaks.

---
## 🚀 Deployment Guide
## Prerequisites
- AWS CLI & Terraform installed.

- An active **AWS CodeStar Connection** to your GitHub account (created via AWS Console).

 1. **Provision Infrastructure**
```
cd terraform
terraform init
terraform plan
terraform apply
```
2. **Connect kubectl to the Cluster**
```
aws eks update-kubeconfig --region us-east-1 --name aws-devops-demo-cluster
```
3. **Deploy Kubernetes Manifests**
```
kubectl apply -f k8s/
kubectl get pods
```
---
## 📈 Key Concepts Demonstrated

- **Infrastructure as Code** — 100% of AWS resources defined in Terraform.
- **Immutable deployments** — Images tagged with Git SHA for perfect version tracking.
- **AWS-Native CI/CD** — Leveraging CodePipeline for lower latency and tighter IAM integration.
- **Least-privilege IAM** — separate roles for the EKS control plane and worker nodes
- **Kubernetes Hardening** —Non-root users, resource limits, and private node networking.

---
