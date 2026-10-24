# -----------------------------------------------------------------------------
# Remote State: Consumo da VPC e Subnets Privadas do infra-network
# -----------------------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.s3_tfstate_bucket
    key    = var.remote_state_network_key != "" ? var.remote_state_network_key : "network/${var.environment}.tfstate"
    region = var.aws_region
  }
}

# -----------------------------------------------------------------------------
# Subnet Group para o Redis (Subnets Privadas)
# -----------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.cluster_name}-redis-subnet-group-${var.environment}"
  subnet_ids = try(data.terraform_remote_state.network.outputs.private_subnet_ids, [])

  tags = {
    Name = "${var.cluster_name}-redis-subnet-group-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# Security Group do Redis (Porta 6379)
# -----------------------------------------------------------------------------
resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis-sg-${var.environment}"
  description = "Security Group para ElastiCache Redis (${var.environment})"
  vpc_id      = try(data.terraform_remote_state.network.outputs.vpc_id, null)

  ingress {
    description = "Acesso Redis a partir das subnets privadas da VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = try(
      data.terraform_remote_state.network.outputs.private_subnet_cidr_blocks,
      [try(data.terraform_remote_state.network.outputs.vpc_cidr_block, "10.0.0.0/16")]
    )
  }

  egress {
    description = "Saida padrao"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-redis-sg-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# Cluster ElastiCache Redis: user-login-cache
# -----------------------------------------------------------------------------
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.cluster_name}-user-login-cache-${var.environment}"
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = {
    Name        = "${var.cluster_name}-user-login-cache-${var.environment}"
    Service     = "register-service"
    Description = "Cache de sessoes ativas e tokens JWT"
  }
}
