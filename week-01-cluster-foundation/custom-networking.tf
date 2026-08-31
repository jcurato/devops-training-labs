# --- VPC CNI Custom Networking (optional) ---
#
# Everything above this file solves IP exhaustion by making the primary
# subnet generously sized (/20 = 4,096 IPs). Custom Networking is a
# different lever entirely: instead of a bigger subnet from the *same*
# CIDR space as your nodes, pods get their IPs from a *separate* CIDR —
# one that doesn't compete with node IPs, other AWS resources, or a
# constrained on-prem-connected VPC CIDR you don't control the size of.
#
# Turn this on with -var="enable_custom_networking=true" to see the AWS
# side of it stood up next to the module you already have. It's off by
# default because it isn't needed here — the /20s already have headroom —
# and toggling it live is the point: same cluster, a second real option.

variable "enable_custom_networking" {
  description = "Stand up a secondary pod-only CIDR + subnets for VPC CNI Custom Networking."
  type        = bool
  default     = false
}

variable "pod_cidr" {
  description = <<-EOT
    AWS recommends carving this from 100.64.0.0/10 (RFC 6598, "shared
    address space") specifically because almost no corporate network
    already uses it — unlike 10.0.0.0/8 or 172.16.0.0/12, which real
    on-prem networks collide with constantly. This is a /16 slice of
    that range, 65,536 addresses, used only by pods.
  EOT
  type        = string
  default     = "100.64.0.0/16"
}

# Associating a second CIDR with an existing VPC — the VPC keeps its
# original 10.20.0.0/16 for nodes/ENIs/everything else already in this
# module; pods get an entirely separate address space layered on top.
resource "aws_vpc_ipv4_cidr_block_association" "pods" {
  count      = var.enable_custom_networking ? 1 : 0
  vpc_id     = aws_vpc.main.id
  cidr_block = var.pod_cidr
}

# One pod subnet per AZ, same /20 convention as the private subnets —
# this is where pod IPs actually come from once Custom Networking is on.
resource "aws_subnet" "pods" {
  count             = var.enable_custom_networking ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = cidrsubnet(var.pod_cidr, 4, count.index)

  tags = {
    Name = "${var.cluster_name}-pods-${var.availability_zones[count.index]}"
    # Not an AWS-enforced tag — a convention so the ENIConfig you create
    # by hand (see outputs.tf) can find the right subnet per AZ without
    # you having to remember subnet IDs.
    "cni/pod-subnet" = "true"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.pods]
}

# --- The route table question you actually asked about. ---
#
# Pod subnets need exactly the same outbound path private subnets already
# have: no direct route to the internet, everything egresses through the
# NAT Gateway. A separate route table isn't strictly required — the
# existing aws_route_table.private would work identically, since the
# route itself (0.0.0.0/0 -> NAT Gateway) is the same. It's split out
# here on purpose, for the same reason the module already runs public
# and private traffic through separate tables: a mistake in one doesn't
# silently change routing for the other, and "which table does this
# subnet use" stays a one-line answer instead of a shared table you have
# to reason about for multiple subnet types at once.
resource "aws_route_table" "pods" {
  count  = var.enable_custom_networking ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-pods"
  }
}

resource "aws_route_table_association" "pods" {
  count          = var.enable_custom_networking ? length(aws_subnet.pods) : 0
  subnet_id      = aws_subnet.pods[count.index].id
  route_table_id = aws_route_table.pods[0].id
}
