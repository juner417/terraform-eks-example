# eks cluster role
resource "aws_iam_role" "ekscluster-role" {
  name = "${var.nick}-eks-cluster"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Name = "${var.nick}-ekscluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "ekscluster-role-att" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.ekscluster-role.name
}

# create eks nodegroup role
resource "aws_iam_role" "eksnodegroup-role" {
  name = "${var.nick}-eks-nodegroup"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eksng-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eksnodegroup-role.name
}

resource "aws_iam_role_policy_attachment" "eksng-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eksnodegroup-role.name
}

resource "aws_iam_role_policy_attachment" "eksng-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eksnodegroup-role.name
}

# for enable controlplane log
resource "aws_cloudwatch_log_group" "ekslog" {
  count             = length(var.ekscluster)
  name              = "/aws/eks/${var.nick}-${var.ekscluster[count.index]}/cluster"
  retention_in_days = 7
}

# create eks cluster
# 3 eks
## public api endpoint
## private api endpoint
## public and private api endpoint

## public
resource "aws_eks_cluster" "eks-public" {
  count    = contains(var.ekscluster, "eks-public") ? 1 : 0
  name     = "${var.nick}-eks-pub"
  role_arn = aws_iam_role.ekscluster-role.arn
  enabled_cluster_log_types = [
    "api",
    "audit",
    "controllerManager",
    "scheduler"
  ]

  vpc_config {
    subnet_ids = concat(
      slice(aws_subnet.private.*.id, 0, 3),
      slice(aws_subnet.public.*.id, 0, 3)
    )
  }

  depends_on = [
    aws_iam_role_policy_attachment.ekscluster-role-att,
    aws_cloudwatch_log_group.ekslog
  ]
}

resource "aws_eks_node_group" "eks-public-pubng" {
  count           = contains(var.ekscluster, "eks-public") ? length(var.public_subnet_cidr) - 1 : 0
  cluster_name    = aws_eks_cluster.eks-public[0].name
  node_group_name = "${aws_eks_cluster.eks-public[0].name}-pub-ng${count.index}"
  node_role_arn   = aws_iam_role.eksnodegroup-role.arn
  subnet_ids = [
    aws_subnet.public[count.index].id
  ]

  scaling_config {
    desired_size = var.ngscale["desired_size"]
    max_size = var.ngscale["max_size"]
    min_size = var.ngscale["min_size"]
  }


  launch_template {
    id      = aws_launch_template.eksng-lt.id
    version = aws_launch_template.eksng-lt.latest_version
  }

  tags = {
    Name = "${aws_eks_cluster.eks-public[0].name}-pub-ng${count.index}"
  }

  depends_on = [
    aws_launch_template.eksng-lt,
    aws_iam_role_policy_attachment.eksng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksng-AmazonEC2ContainerRegistryReadOnly
  ]
}

resource "aws_eks_node_group" "eks-public-pring" {
  count           = contains(var.ekscluster, "eks-public") ? length(var.public_subnet_cidr) - 1 : 0
  cluster_name    = aws_eks_cluster.eks-public[0].name
  node_group_name = "${aws_eks_cluster.eks-public[0].name}-pri-ng${count.index}"
  node_role_arn   = aws_iam_role.eksnodegroup-role.arn
  subnet_ids = [
    aws_subnet.private[count.index].id
  ]

  scaling_config {
    desired_size = var.ngscale["desired_size"]
    max_size = var.ngscale["max_size"]
    min_size = var.ngscale["min_size"]
  }

  launch_template {
    id      = aws_launch_template.eksng-lt.id
    version = aws_launch_template.eksng-lt.latest_version
  }

  tags = {
    Name = "${aws_eks_cluster.eks-public[0].name}-pri-ng${count.index}"
  }

  depends_on = [
    aws_launch_template.eksng-lt,
    aws_iam_role_policy_attachment.eksng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksng-AmazonEC2ContainerRegistryReadOnly
  ]
}

# private
resource "aws_eks_cluster" "eks-private" {
  count    = contains(var.ekscluster, "eks-private") ? 1 : 0
  name     = "${var.nick}-eks-pri"
  role_arn = aws_iam_role.ekscluster-role.arn
  enabled_cluster_log_types = [
    "api",
    "audit",
    "controllerManager",
    "scheduler"
  ]

  vpc_config {
    subnet_ids = concat(
      slice(aws_subnet.private.*.id, 0, 3),
      slice(aws_subnet.public.*.id, 0, 3)
    )
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.ekscluster-role-att,
    aws_cloudwatch_log_group.ekslog
  ]
}

resource "aws_eks_node_group" "eks-private-pubng" {
  count           = contains(var.ekscluster, "eks-private") ? length(var.public_subnet_cidr) - 1 : 0
  cluster_name    = aws_eks_cluster.eks-private[0].name
  node_group_name = "${aws_eks_cluster.eks-private[0].name}-pub-ng${count.index}"
  node_role_arn   = aws_iam_role.eksnodegroup-role.arn
  subnet_ids = [
    aws_subnet.public[count.index].id
  ]

  scaling_config {
    desired_size = var.ngscale["desired_size"]
    max_size = var.ngscale["max_size"]
    min_size = var.ngscale["min_size"]
  }

  launch_template {
    id      = aws_launch_template.eksng-lt.id
    version = aws_launch_template.eksng-lt.latest_version
  }

  tags = {
    Name = "${aws_eks_cluster.eks-private[0].name}-pub-ng${count.index}"
  }

  depends_on = [
    aws_launch_template.eksng-lt,
    aws_iam_role_policy_attachment.eksng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksng-AmazonEC2ContainerRegistryReadOnly
  ]
}

resource "aws_eks_node_group" "eks-private-pring" {
  count           = contains(var.ekscluster, "eks-private") ? length(var.public_subnet_cidr) - 1 : 0
  cluster_name    = aws_eks_cluster.eks-private[0].name
  node_group_name = "${aws_eks_cluster.eks-private[0].name}-pri-ng${count.index}"
  node_role_arn   = aws_iam_role.eksnodegroup-role.arn
  subnet_ids = [
    aws_subnet.private[count.index].id
  ]

  scaling_config {
    desired_size = var.ngscale["desired_size"]
    max_size = var.ngscale["max_size"]
    min_size = var.ngscale["min_size"]
  }

  launch_template {
    id      = aws_launch_template.eksng-lt.id
    version = aws_launch_template.eksng-lt.latest_version
  }

  tags = {
    Name = "${aws_eks_cluster.eks-private[0].name}-pri-ng${count.index}"
  }

  depends_on = [
    aws_launch_template.eksng-lt,
    aws_iam_role_policy_attachment.eksng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksng-AmazonEC2ContainerRegistryReadOnly
  ]
}

# private and public
resource "aws_eks_cluster" "eks-pp" {
  count    = contains(var.ekscluster, "eks-pp") ? 1 : 0
  name     = "${var.nick}-eks-pp"
  role_arn = aws_iam_role.ekscluster-role.arn
  enabled_cluster_log_types = [
    "api",
    "audit",
    "controllerManager",
    "scheduler"
  ]

  vpc_config {
    subnet_ids = concat(
      slice(aws_subnet.private.*.id, 0, 3),
      slice(aws_subnet.public.*.id, 0, 3)
    )
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ekscluster-role-att,
    aws_cloudwatch_log_group.ekslog
  ]
}

resource "aws_eks_node_group" "eks-pp-pubng" {
  count           = contains(var.ekscluster, "eks-pp") ? length(var.public_subnet_cidr) - 1 : 0
  cluster_name    = aws_eks_cluster.eks-pp[0].name
  node_group_name = "${aws_eks_cluster.eks-pp[0].name}-pub-ng${count.index}"
  node_role_arn   = aws_iam_role.eksnodegroup-role.arn
  subnet_ids = [
    aws_subnet.public[count.index].id
  ]

  scaling_config {
    desired_size = var.ngscale["desired_size"]
    max_size = var.ngscale["max_size"]
    min_size = var.ngscale["min_size"]
  }

  launch_template {
    id      = aws_launch_template.eksng-lt.id
    version = aws_launch_template.eksng-lt.latest_version
  }

  tags = {
    Name = "${aws_eks_cluster.eks-pp[0].name}-pub-ng${count.index}"
  }

  depends_on = [
    aws_launch_template.eksng-lt,
    aws_iam_role_policy_attachment.eksng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksng-AmazonEC2ContainerRegistryReadOnly
  ]
}

resource "aws_eks_node_group" "eks-pp-pring" {
  count           = contains(var.ekscluster, "eks-pp") ? length(var.public_subnet_cidr) - 1 : 0
  cluster_name    = aws_eks_cluster.eks-pp[0].name
  node_group_name = "${aws_eks_cluster.eks-pp[0].name}-pri-ng${count.index}"
  node_role_arn   = aws_iam_role.eksnodegroup-role.arn
  subnet_ids = [
    aws_subnet.public[count.index].id
  ]

  scaling_config {
    desired_size = var.ngscale["desired_size"]
    max_size = var.ngscale["max_size"]
    min_size = var.ngscale["min_size"]
  }

  launch_template {
    id      = aws_launch_template.eksng-lt.id
    version = aws_launch_template.eksng-lt.latest_version
  }

  tags = {
    Name = "${aws_eks_cluster.eks-pp[0].name}-pri-ng${count.index}"
  }

  depends_on = [
    aws_launch_template.eksng-lt,
    aws_iam_role_policy_attachment.eksng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksng-AmazonEC2ContainerRegistryReadOnly
  ]
}
