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

variable "php_image_tag" {
  description = "Tag da imagem PHP a ser implantada."
  type        = string
  default     = "v3"
}

variable "nginx_image_tag" {
  description = "Tag da imagem Nginx a ser implantada."
  default     = "v3"
}