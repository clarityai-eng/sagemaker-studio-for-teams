output "key_filename" {
  description = "location of PEM key file"
  value       = var.key_filename
}

output "ip" {
  description = "IP address"
  value       = aws_instance.ec2.private_ip
}

output "target" {
  description = "instance ID"
  value       = aws_instance.ec2.id
}

output "profile" {
  description = "AWS profile"
  value       = var.profile
}
