output "alb_dns" {
  value = aws_lb.alb.dns_name
}
output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}
output "s3_bucket_name" {
  value = aws_s3_bucket.app_bucket.bucket
}
output "rds_endpoint" {
  value = aws_db_instance.postgres.address
  sensitive = false
}
output "sns_topic_arn" { value = aws_sns_topic.s3_topic.arn }
