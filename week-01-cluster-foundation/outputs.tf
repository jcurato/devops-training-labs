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

output "pod_subnet_ids" {
  description = "Only populated when enable_custom_networking=true."
  value       = var.enable_custom_networking ? aws_subnet.pods[*].id : []
}

# The AWS side (secondary CIDR, pod subnets, route table) is Terraform's
# job. ENIConfig is a Kubernetes CRD, not an AWS resource — it lives
# inside the cluster, so it's a kubectl step after apply, not something
# this module creates for you. This output writes the exact commands.
output "custom_networking_next_steps" {
  description = "Manual kubectl steps to finish enabling Custom Networking, once the cluster exists."
  value = var.enable_custom_networking ? join("\n", concat(
    ["kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true"],
    [
      for i, az in var.availability_zones :
      "cat <<EOF | kubectl apply -f -\napiVersion: crd.k8s.amazonaws.com/v1alpha1\nkind: ENIConfig\nmetadata:\n  name: ${az}\nspec:\n  subnet: ${aws_subnet.pods[i].id}\n  securityGroups:\n    - ${aws_eks_cluster.main.vpc_config[0].cluster_security_group_id}\nEOF"
    ],
    ["kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone"],
    ["# New pods now get IPs from ${var.pod_cidr}. Existing pods keep their current IP until they're recreated."]
  )) : "enable_custom_networking is false — nothing to do"
}
