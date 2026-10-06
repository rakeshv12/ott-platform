output "master_user_secret_arn" {
  description = "ARN of the AWS-managed RDS master credentials secret"
  value       = aws_db_instance.database.master_user_secret[0].secret_arn
}