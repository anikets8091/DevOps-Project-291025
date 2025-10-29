resource "aws_ecr_repository" "app" {
  name = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"
}

# ALB
resource "aws_lb" "alb" {
  name = "${local.name_prefix}-alb"
  internal = false
  load_balancer_type = "application"
  subnets = [for s in aws_subnet.public : s.id]
  security_groups = [aws_security_group.alb_sg.id]
  enable_deletion_protection = false
  tags = { Name = "${local.name_prefix}-alb" }
}

resource "aws_security_group" "alb_sg" {
  name = "${local.name_prefix}-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [var.allowed_ip_cidr]
  }
  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
     }
}

# ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = "${local.name_prefix}-ecs-cluster"
}

# Task role for app
data "aws_iam_policy_document" "ecs_task_assume" {
  statement { 
    effect="Allow" 
    principals{
        type="Service"; 
        identifiers=["ecs-tasks.amazonaws.com"]} 
    actions=["sts:AssumeRole"] 
    }
}
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

# Task definition (Fargate)
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name = "app"
      image = "${aws_ecr_repository.app.repository_url}:${var.docker_image_tag}"
      essential = true
      portMappings = [{ containerPort = var.app_port; hostPort = var.app_port; protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

# Target group and listener
resource "aws_lb_target_group" "app_tg" {
  name = "${local.name_prefix}-tg"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check { 
    path = "/"
    protocol = "HTTP"
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher = "200-399" 
    }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action { 
    type = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn 
    }
}

# ECS service (Fargate) attached to ALB
resource "aws_ecs_service" "app_service" {
  name = "${local.name_prefix}-service"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count = 2
  launch_type = "FARGATE"
  network_configuration {
    subnets = [for s in aws_subnet.private : s.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name = "app"
    container_port = var.app_port
  }
  depends_on = [aws_lb_listener.http]
}

# Security Group for ECS tasks
resource "aws_security_group" "ecs_sg" {
  name = "${local.name_prefix}-ecs-sg"
  vpc_id = aws_vpc.main.id
  ingress { 
    from_port = var.app_port
    to_port = var.app_port
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id] 
    }
  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }
}
