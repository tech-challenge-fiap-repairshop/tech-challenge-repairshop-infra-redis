provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "RepairShop"
      Component   = "ElastiCache-Redis"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
