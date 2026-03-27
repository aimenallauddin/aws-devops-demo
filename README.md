# AWS DevOps Demo — Node.js · EKS · Terraform · GitHub Actions

A end-to-end DevOps project demonstrating a production-style CI/CD pipeline for a Node.js application deployed to AWS EKS (Kubernetes), with infrastructure provisioned via Terraform.

---

## Tech Stack

| Layer | Tool |
|---|---|
| Cloud | AWS (EKS, ECR, VPC, IAM) |
| Infrastructure as Code | Terraform |
| Containerisation | Docker (multi-stage build) |
| Container Orchestration | Kubernetes (EKS) |
| CI/CD | GitHub Actions |
| Language | Node.js 20 |

---

## Pipeline Overview

Every push to `main` triggers a three-stage automated pipeline:

```
Push to main
     │
     ▼
┌─────────────┐
│  1. BUILD   │  Docker multi-stage build → push to AWS ECR
└──────┬──────┘     (tagged with Git short SHA for traceability)
       │
       ▼
┌─────────────┐
│  2. DEPLOY  │  (Commented this stage since i don't have EKS cluster) kubectl rolling update on EKS
└─────────────┘     zero-downtime · auto-rollback on failure 
```

Pull requests run the **test stage only** — nothing is deployed until code merges to `main`.

---

## Infrastructure

Provisioned with Terraform. Running `terraform apply` creates:

- **VPC** — isolated network with public and private subnets across 2 availability zones
- **NAT Gateway** — allows private subnet resources to reach the internet
- **EKS Cluster** — managed Kubernetes control plane (v1.29)
- **Node Group** — 2× `t3.medium` EC2 worker nodes (auto-scales to 4)
- **ECR Repository** — private Docker image registry with scan-on-push enabled

```
terraform/
├── main.tf      # Provider, backend, variables, outputs
├── vpc.tf       # VPC, subnets, NAT gateway, routing
└── eks.tf       # EKS cluster, node group, ECR, IAM roles
```

---

## Kubernetes Setup

Two manifests in `k8s/`:

**`deployment.yaml`**
- 2 replicas with rolling update strategy (zero downtime)
- CPU and memory resource limits defined
- Liveness and readiness probes on `/health`
- Non-root container user for security

**`service.yaml`**
- LoadBalancer service — provisions an AWS ALB automatically
- HorizontalPodAutoscaler — scales pods when CPU exceeds 70%

---

## Docker — Multi-Stage Build

The `Dockerfile` uses three stages to keep the production image small and secure:

```
Stage 1: deps     Install production npm dependencies only
Stage 2: builder  Copy all deps + source, run npm build
Stage 3: runner   Copy only the build output — no dev tools, no source
```

Result: a minimal Alpine-based image running as a non-root user.

---

## How to Run Locally

**Prerequisites:** Node.js 20, Docker, AWS CLI, Terraform ≥ 1.7, kubectl

```bash
# Clone the repo
git clone https://github.com/your-username/aws-devops-demo.git
cd aws-devops-demo

# Build and run with Docker
docker build -t aws-devops-demo .
docker run -p 3000:3000 aws-devops-demo
# → http://localhost:3000
```

---

## How to Deploy to AWS

```bash
# 1. Provision infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 2. Connect kubectl to the new cluster
aws eks update-kubeconfig --region us-east-1 --name aws-devops-demo-cluster

# 3. Deploy the app
kubectl apply -f k8s/
kubectl get pods    # verify pods are running
```

After that, pushing to `main` triggers the GitHub Actions pipeline automatically.

---

## GitHub Secrets Required

| Secret | What it is |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret |
| `ECR_REGISTRY` | e.g. `123456789.dkr.ecr.us-east-1.amazonaws.com` |

---

## Key Concepts Demonstrated

- **Infrastructure as Code** — all AWS resources defined in Terraform, no manual console clicks
- **Immutable deployments** — every release is a new Docker image tagged with Git SHA
- **Zero-downtime deploys** — Kubernetes rolling update with `maxUnavailable: 0`
- **Least-privilege IAM** — separate roles for the EKS control plane and worker nodes
- **Secure container** — non-root user, resource limits, health probes
- **Automated pipeline** — no manual steps between a code push and a live deployment
