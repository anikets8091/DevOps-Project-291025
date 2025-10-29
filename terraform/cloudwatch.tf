resource "aws_cloudwatch_log_group" "app_logs" {
  name = "/ecs/${local.name_prefix}-app"
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name = "${local.name_prefix}-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  period = 300
  statistic = "Average"
  threshold = 75
  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.app_service.name
  }
  alarm_actions = [] # add SNS topic ARN for notifications if desired
}
