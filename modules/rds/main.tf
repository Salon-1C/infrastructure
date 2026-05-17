resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project}/db-password"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Project = var.project }
}

locals {
  engine         = var.engine
  engine_version = coalesce(var.engine_version, var.engine == "postgres" ? "16" : "8.0")
  port           = coalesce(var.port, var.engine == "postgres" ? 5432 : 3306)
  identifier     = var.engine == "postgres" ? "${var.project}-postgres" : "${var.project}-mysql"
}

resource "aws_db_instance" "this" {
  identifier        = local.identifier
  engine            = local.engine
  engine_version    = local.engine_version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  port              = local.port

  db_name  = var.db_name
  username = var.username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = { Project = var.project }
}
