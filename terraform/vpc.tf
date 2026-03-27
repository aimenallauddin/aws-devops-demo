# ─────────────────────────────────────────────────────────────
# VPC (Virtual Private Cloud)
# An isolated network in AWS where all our resources live.
# ─────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true    
  enable_dns_hostnames = true    
  tags = { Name = "${var.project_name}-vpc" }
}

# Internet Gateway: the door between our VPC and the public internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ── Subnets ───────────────────────────────────────────────────

# Public subnets: resources here get a public IP (e.g. load balancers)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"   # Tells EKS to use these for load balancers
  }
}

# Private subnets: resources here have no public IP (e.g. EKS worker nodes)
# They reach the internet via the NAT gateway instead
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name                              = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"   # Tells EKS to use these for internal LBs
  }
}

# ── NAT Gateway ───────────────────────────────────────────────
# Allows private subnet resources (EKS nodes) to reach the internet
# (e.g. to pull Docker images) without having a public IP themselves

resource "aws_eip" "nat" {
  domain = "vpc"   # Elastic IP for the NAT gateway
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id   # NAT gateway lives in a public subnet
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "${var.project_name}-nat" }
}

# ── Route Tables ──────────────────────────────────────────────
# Route tables control where network traffic is directed

# Public route table: send all traffic to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table: send all traffic through the NAT gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Fetch the list of available AZs in the chosen region dynamically
data "aws_availability_zones" "available" {
  state = "available"
}
