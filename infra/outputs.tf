output "redis_endpoint" {
  description = "Endpoint do cluster Redis"
  value       = try(aws_elasticache_cluster.redis.cache_nodes[0].address, "")
}

output "redis_port" {
  description = "Porta de conexao do cluster Redis"
  value       = aws_elasticache_cluster.redis.port
}

output "redis_security_group_id" {
  description = "ID do Security Group do Redis"
  value       = aws_security_group.redis.id
}
