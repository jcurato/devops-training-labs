output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster you just built."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "estimated_hourly_cost_usd" {
  description = "Rough — control plane + NAT Gateway + its public IP + 2x t3.medium, at list price. Doesn't include data transfer, and instance pricing varies by region."
  value       = "~$0.23/hr (~$170/month if left running) — tear this down with `terraform destroy` when you're not actively using it"
}
