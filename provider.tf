provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket  = "s3-fiap-soat-fase3"
    key     = "application/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}

data "aws_eks_cluster" "eks" {
  name = var.aws_cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.aws_cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}