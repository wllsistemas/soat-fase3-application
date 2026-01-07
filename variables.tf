variable "aws_cluster_name" {
  description = "O nome do cluster EKS na AWS."
  type        = string
  default     = "fiap-soat-eks-cluster" 
}

variable "aws_region" {
  description = "A região da AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-2" 
}