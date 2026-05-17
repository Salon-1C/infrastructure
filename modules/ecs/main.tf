data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  discovery_namespace = "${var.project}.local"
  internal_origin     = "http://${aws_lb.alb.dns_name}"
}

# ── App secrets ───────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project}/jwt-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}

resource "aws_secretsmanager_secret" "hls_signing_secret" {
  name                    = "${var.project}/hls-signing-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "hls_signing_secret" {
  secret_id     = aws_secretsmanager_secret.hls_signing_secret.id
  secret_string = var.hls_signing_secret
}

resource "aws_secretsmanager_secret" "firebase_sa" {
  name                    = "${var.project}/firebase-service-account"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "firebase_sa" {
  secret_id     = aws_secretsmanager_secret.firebase_sa.id
  secret_string = var.firebase_service_account_json
}

resource "aws_secretsmanager_secret" "stream_key" {
  name                    = "${var.project}/stream-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "stream_key" {
  secret_id     = aws_secretsmanager_secret.stream_key.id
  secret_string = var.stream_key
}

resource "aws_secretsmanager_secret" "activities_secret_key_base" {
  name                    = "${var.project}/activities-secret-key-base"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "activities_secret_key_base" {
  secret_id     = aws_secretsmanager_secret.activities_secret_key_base.id
  secret_string = var.activities_secret_key_base
}

data "aws_secretsmanager_secret_version" "activities_db_password" {
  secret_id = var.activities_db_password_secret_arn
}

resource "aws_secretsmanager_secret" "activities_database_url" {
  name                    = "${var.project}/activities-database-url"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "activities_database_url" {
  secret_id     = aws_secretsmanager_secret.activities_database_url.id
  secret_string = "postgresql://${var.activities_db_user}:${data.aws_secretsmanager_secret_version.activities_db_password.secret_string}@${var.activities_db_host}:5432/${var.activities_db_name}"
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
locals {
  log_services = [
    "business-logic",
    "stream-engine",
    "record-service",
    "activities-ms",
    "recommendations-ms",
    "blume-wa",
  ]
}

resource "aws_cloudwatch_log_group" "services" {
  for_each          = toset(local.log_services)
  name              = "/ecs/${var.project}/${each.value}"
  retention_in_days = 14
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = var.project

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── Cloud Map (service discovery) ─────────────────────────────────────────────
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = local.discovery_namespace
  description = "Blume ECS service discovery"
  vpc         = var.vpc_id
}

locals {
  rabbitmq_amqp_url = "amqp://guest:guest@rabbitmq.${local.discovery_namespace}:5672/"
}

resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/ecs/${var.project}/rabbitmq"
  retention_in_days = 14
}
