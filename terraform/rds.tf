resource "aws_secretsmanager_secret" "db_secret" {
  name = "${local.name_prefix}-db-secret"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = "placeholder"
  })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "db_subnets" {
  name = "${local.name_prefix}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"
  engine = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"
  name = "appdb"
  username = var.db_username
  password = var.db_password
  allocated_storage = 20
  storage_type = "gp2"
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az = false
}
resource "aws_security_group" "db_sg" {
  name = "${local.name_prefix}-db-sg"
  vpc_id = aws_vpc.main.id
  ingress { 
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
     }
  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
}
}
