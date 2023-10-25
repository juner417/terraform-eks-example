# resource's nickname
variable "nick" {
  type    = string
  default = "gonz"
}

# region info
variable "region" {
  type    = string
  default = "ap-northeast-2"
}

# az info
variable "az" {
  type = list(string)
  default = [
    "ap-northeast-2a",
    "ap-northeast-2b",
    "ap-northeast-2c",
    "ap-northeast-2d"
  ]
}

# vpc info
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type = list(string)
  default = [
    "10.0.32.0/20",
    "10.0.64.0/20",
    "10.0.96.0/20",
    "10.0.112.0/20"
  ]
}

variable "private_subnet_cidr" {
  type = list(string)
  default = [
    "10.0.16.0/20",
    "10.0.48.0/20",
    "10.0.80.0/20",
    "10.0.128.0/20"
  ]
}

variable "ekscluster" {
  type = list(string)
  default = [
    "eks-public",
    "eks-private",
    "eks-pp"
  ]
}

variable "ngscale" {
  type = object({
    desired_size = number
    max_size = number
    min_size = number
  })

  default = {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }
}

variable "policy-tags" {
  type = map(any)
  default = {
    Team  = "teamname"
  }
}
