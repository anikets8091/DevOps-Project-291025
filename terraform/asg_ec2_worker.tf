resource "aws_launch_template" "worker_lt" {
  name_prefix = "${local.name_prefix}-worker-"
  image_id = data.aws_ami.amzn2.id
  instance_type = var.asg_instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }
  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
# install docker, ecs or app logic; placeholder
EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${local.name_prefix}-worker" }
  }
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners = ["amazon"]
  filter { 
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] 
}
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${local.name_prefix}-worker-profile"
  role = aws_iam_role.worker_role.name
}

data "aws_iam_policy_document" "worker_assume" {
  statement { 
    effect="Allow" 
    principals{
        type="Service" 
        identifiers=["ec2.amazonaws.com"]
    } 
    actions=["sts:AssumeRole"] 
    }
}
resource "aws_iam_role" "worker_role" {
  name = "${local.name_prefix}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.worker_assume.json
}
resource "aws_iam_role_policy_attachment" "worker_attach" {
  role = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_autoscaling_group" "worker_asg" {
  name = "${local.name_prefix}-asg"
  max_size = var.asg_max_size
  min_size = var.asg_min_size
  desired_capacity = var.asg_min_size
  vpc_zone_identifier = [for s in aws_subnet.private : s.id]
  launch_template {
    id = aws_launch_template.worker_lt.id
    version = "$Latest"
  }
  tag { 
    key = "Name"
    value = "${local.name_prefix}-asg"
    propagate_at_launch = true 
    }
}
