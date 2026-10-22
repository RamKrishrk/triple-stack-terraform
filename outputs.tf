output "web_url" {
  description = "Public entry point (web tier ALB)"
  value       = "http://${aws_lb.web.dns_name}"
}

output "app_alb_dns" {
  description = "Internal app tier ALB DNS"
  value       = aws_lb.app.dns_name
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the DB master password"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "vpc_id" {
  value = aws_vpc.main.id
}
