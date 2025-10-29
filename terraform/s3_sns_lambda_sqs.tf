resource "aws_s3_bucket" "app_bucket" {
  bucket = "${local.name_prefix}-uploads-${random_id.bucket_id.hex}"
  tags = { Name = "${local.name_prefix}-uploads" }
  force_destroy = false
}

resource "random_id" "bucket_id" { byte_length = 4 }

# SNS topic
resource "aws_sns_topic" "s3_topic" {
  name = "${local.name_prefix}-s3-topic"
}

# SQS queue
resource "aws_sqs_queue" "app_queue" {
  name = "${local.name_prefix}-queue"
  visibility_timeout_seconds = 30
}

# Subscribe SQS to SNS
resource "aws_sns_topic_subscription" "sns_sqs" {
  topic_arn = aws_sns_topic.s3_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.app_queue.arn
  raw_message_delivery = true
}

# Allow SNS to send to SQS
resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.app_queue.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid = "Allow-SNS-SendMessage",
      Effect = "Allow",
      Principal = { AWS = "*" },
      Action = "sqs:SendMessage",
      Resource = aws_sqs_queue.app_queue.arn,
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.s3_topic.arn } }
    }]
  })
}

# Lambda zip upload via Terraform local file (simplified: inline archive)
data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "${path.module}/../lambda/s3_to_sns_lambda.py"
  output_path = "${path.module}/../lambda/s3_to_sns_lambda.zip"
}

resource "aws_lambda_function" "s3_lambda" {
  filename = "${path.module}/../lambda/s3_to_sns_lambda.zip"
  function_name = "${local.name_prefix}-s3-lambda"
  handler = "s3_to_sns_lambda.handler"
  runtime = "python3.11"
  role = aws_iam_role.lambda_role.arn
  environment { variables = { SNS_TOPIC_ARN = aws_sns_topic.s3_topic.arn } }
  timeout = 30
}

# S3 bucket notification to Lambda
resource "aws_s3_bucket_notification" "bucket_notify" {
  bucket = aws_s3_bucket.app_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_lambda.arn
    events = ["s3:ObjectCreated:*"]
  }
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.app_bucket.arn
}
