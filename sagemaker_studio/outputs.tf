output "bastion_connection_secret" {
  description = "Bastion connection secret"
  value       = aws_secretsmanager_secret.connection.id
}

output "bastion_security_group" {
  description = "Bastion sewcurity group"
  value       = aws_security_group.bastion.id
}
