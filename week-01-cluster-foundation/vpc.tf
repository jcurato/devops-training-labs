resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.cluster_name
  }
}

# --- Public subnets: one per AZ, for the NAT Gateway and the ALB later. ---
# Deliberately small (/24 = 256 IPs) — nothing here needs many addresses;
# the NAT Gateway ENI and the load balancer's ENIs live in these.
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1" # tells the AWS Load Balancer Controller this subnet is fair game for public ALBs
  }
}

# --- Private subnets: where the worker nodes actually run. ---
#
# This is the subnet-sizing mistake this module exists to demonstrate.
# The VPC CNI gives every pod a *real* VPC IP address — not an overlay
# address like most other CNIs. That means your pod capacity is capped by
# subnet size, not by CPU/memory, and it's easy to size a subnet like
# you're thinking about EC2 instances instead of pods.
#
# /20 = 4,096 IPs per subnet. A /24 (256 IPs) looks "plenty" for a
# handful of nodes — until you remember each node can host dozens of pods,
# each pod eats a real address, and ENI trunking/prefix delegation still
# have limits. A team that sized this /24 in year one is often back here
# in year two asking why new pods sit in "Pending" during a scale-out —
# not from a lack of CPU, but a lack of IPs left in the subnet.
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 1) # /20 blocks

  tags = {
    Name                              = "${var.cluster_name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# --- One NAT Gateway, not one per AZ. ---
#
# This is a cost decision, made explicit rather than left as an accident.
# A NAT Gateway per AZ (the HA-correct answer) means an AZ outage doesn't
# take your nodes' internet access with it — and it also multiplies the
# ~$33/month base charge by however many AZs you have. For a training lab
# that gets torn down after each session, that trade-off isn't worth it.
# For a production cluster, it usually is. Revisit this in Week 7 (cost
# and scale) with real numbers instead of a rule of thumb.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.cluster_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
