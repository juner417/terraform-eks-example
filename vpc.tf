provider "aws" {
  region = var.region

  default_tags {
    tags = var.policy-tags
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "${var.nick}-vpc"
  }
}

# NOTE. last subnet is only private, No nat gw
resource "aws_subnet" "private" {
  count             = length(var.az)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = var.az[count.index]

  tags = {
    Name = "${var.nick}-private-${var.az[count.index]}"
    # "kubernetes.io/cluster/${aws_eks_cluster.eks-public.name}" = "shared"
    # "kubernetes.io/cluster/${aws_eks_cluster.eks-private.name}" = "shared"
    # "kubernetes.io/cluster/${aws_eks_cluster.eks-pp.name}" = "shared"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.az)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr[count.index]
  availability_zone       = var.az[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.nick}-public-${var.az[count.index]}"
    # "kubernetes.io/cluster/${aws_eks_cluster.eks-public.name}" = "shared"
    # "kubernetes.io/cluster/${aws_eks_cluster.eks-private.name}" = "shared"
    # "kubernetes.io/cluster/${aws_eks_cluster.eks-pp.name}" = "shared"
  }
}

## igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.nick}-igw-main"
  }
}

## nat gw on each private subnet's az, except last subnet
resource "aws_eip" "nat_eip" {
  count = length(var.private_subnet_cidr) - 1
  vpc   = true

  tags = {
    Name = "nat-${count.index}"
  }
}

resource "aws_nat_gateway" "natgw-subnet" {
  count         = length(var.private_subnet_cidr) - 1
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.nick}-natgw-${var.az[count.index]}"
  }
}

# route table
## main route(default route),
## public route(all pub subnet),
## private route(each pri subnets)

## main default route table
## NOTE. https://registry.terraform.io/providers/hashicorp/aws/3.3.0/docs/resources/default_route_table
resource "aws_default_route_table" "default-rt" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = {
    Name = "${var.nick}-rt-main"
  }
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_default_route_table.default-rt.id
}

## public route(all pub subnet) associate with pub subnets
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.nick}-rt-public"
  }
}

# public route association all pub subnets
resource "aws_route_table_association" "pubic-asso" {
  count          = length(var.az)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public-rt.id
}

## private route(each pri subnets) associate with each pri subnets and NAT gw
resource "aws_route_table" "private-rt" {
  count  = length(var.az) - 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw-subnet[count.index].id
  }

  tags = {
    Name = "${var.nick}-rt-private-${var.az[count.index]}"
  }
}

resource "aws_route_table_association" "private-asso" {
  count          = length(var.az) - 1
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private-rt[count.index].id
}
