# --- IAM role for the EKS control plane itself. ---
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

    # Public endpoint access is on here for one reason: a training lab
    # needs `kubectl` to reach the API server from wherever the student's
    # laptop happens to be, with no VPN or bastion host to set up first.
    #
    # That is a real trade-off, not a default you should carry into
    # production unmodified — a public API endpoint is attack surface.
    # Week 2 (identity and access) is where this gets revisited: private
    # endpoint + a bastion, or a public endpoint locked to specific CIDRs
    # via `public_access_cidrs` instead of the open 0.0.0.0/0 this
    # defaults to.
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# --- IAM role for the worker nodes. ---
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- The node group itself: managed, not self-managed, not Karpenter. ---
#
# Three real options existed here, and "managed node group" isn't the
# universally correct one — it's the right one for this module:
#
#   - Self-managed nodes give you the most control (custom AMIs, custom
#     bootstrap scripts) and the most operational burden — you own the
#     Auto Scaling Group, the launch template, and every AMI upgrade.
#   - Karpenter provisions nodes per-pod-requirement instead of in fixed
#     groups, which is usually cheaper and faster to scale — at the cost
#     of a second system to understand on top of Kubernetes itself.
#   - A managed node group is AWS running the ASG and handling node
#     lifecycle for you. Less flexible than either alternative, and the
#     right default until you have a specific reason to reach past it.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id # nodes stay off the public subnets — outbound internet goes through the NAT Gateway, not a public IP

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}
