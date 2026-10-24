variable "aws_region" {
  description = "Região da AWS para provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de execução (dev, hml, prd)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Nome base do recurso"
  type        = string
  default     = "repairshop"
}

variable "node_type" {
  description = "Tipo de instância do nó Redis"
  type        = string
  default     = "cache.t3.micro"
}

variable "s3_tfstate_bucket" {
  description = "Bucket S3 do remote state da infraestrutura de rede"
  type        = string
  default     = "fiap-repairshop2"
}

variable "remote_state_network_key" {
  description = "Key do remote state da rede VPC"
  type        = string
  default     = ""
}
