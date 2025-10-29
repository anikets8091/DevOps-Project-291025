resource "aws_iam_role" "ecs_task_exec" {
  name = "${local.name_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume-4.json
}

data "aws_iam_policy_document" "ecs_task_assume-4" {
  statement {
    effect = "Allow"
    principals { 
        type = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"] 
        }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach" {
  role = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Lambda role
data "aws_iam_policy_document" "lambda_assume" {
  statement { 
    effect="Allow"
    principals{
        type="Service"
        identifiers=["lambda.amazonaws.com"]} 
    actions=["sts:AssumeRole"] }
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_attach" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_sns_policy" {
  name = "${local.name_prefix}-lambda-sns"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = "*" }
    ]
  })
}
resource "aws_iam_policy_attachment" "lambda_sns_attach" {
  name = "${local.name_prefix}-lambda-sns-attach"
  policy_arn = aws_iam_policy.lambda_sns_policy.arn
  roles = [aws_iam_role.lambda_role.name]
}
