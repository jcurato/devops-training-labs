variable "aws_region" {
  description = "Where the cluster lives. ap-south-1 (Mumbai) by default — change it, don't leave it assumed."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "The AWS CLI profile to use — set up with `aws configure --profile <name>` before running this."
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "EKS cluster name. Shows up in kubeconfig, IAM role names, and your AWS bill line items."
  type        = string
  default     = "week01-cluster-foundation"
}

variable "vpc_cidr" {
  description = <<-EOT
    The whole VPC's address space. /16 gives 65,536 IPs — generous on
    purpose, because the mistake this course is about is picking subnets
    too small for EKS's actual IP appetite (see subnet comments below).
  EOT
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "EKS requires the control plane to span at least 2 AZs. Two is the floor, not a stylistic choice."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "node_instance_types" {
  description = <<-EOT
    t3.medium — enough vCPU/RAM to run real workloads for a lab, cheap
    enough that leaving it running for a session doesn't hurt. Not a
    production sizing recommendation; that's a capacity-planning exercise
    this course doesn't cover.
  EOT
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}
