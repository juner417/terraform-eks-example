# for getting eks kubeconfig update with aws cli
output "eks-public-cluster-name" {
  value = one(aws_eks_cluster.eks-public[*].name)
}
output "eks-public-endpoint" {
  value = one(aws_eks_cluster.eks-public[*].endpoint)
}

output "eks-private-cluster-name" {
  value = one(aws_eks_cluster.eks-private[*].name)
}
output "eks-private-endpoint" {
  value = one(aws_eks_cluster.eks-private[*].endpoint)
}

output "eks-pp-cluster-name" {
  value = one(aws_eks_cluster.eks-pp[*].name)
}
output "eks-pp-endpoint" {
  value = one(aws_eks_cluster.eks-pp[*].endpoint)
}

output "bastion-endpoint" {
  value = aws_instance.bastion.public_ip
}
output "bastion-domain" {
  value = aws_instance.bastion.public_dns
}

