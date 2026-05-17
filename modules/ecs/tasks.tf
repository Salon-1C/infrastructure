locals {
  log_opts = {
    region = data.aws_region.current.name
  }
}

resource "aws_ecs_task_definition" "business_logic" {
  family                   = "${var.project}-business-logic"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.business_logic_cpu
  memory                   = var.business_logic_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.business_logic_task_role_arn

  container_definitions = jsonencode([{
    name         = "api"
    image        = "${var.blume_backend_image_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 8082, protocol = "tcp" }]
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = "admin" },
      { name = "ALLOWED_ORIGIN", value = var.allowed_origin },
      { name = "JWT_EXPIRATION_SECONDS", value = "86400" },
      { name = "HLS_URL_TTL_SECONDS", value = "3600" },
      { name = "MAIL_HOST", value = var.mail_host },
      { name = "MAIL_PORT", value = tostring(var.mail_port) },
      { name = "MAIL_USERNAME", value = var.mail_username },
      { name = "FIREBASE_SERVICE_ACCOUNT_PATH", value = "/run/secrets/firebase-sa.json" },
    ]
    secrets = [
      { name = "DB_PASSWORD", valueFrom = var.db_password_secret_arn },
      { name = "JWT_SECRET", valueFrom = aws_secretsmanager_secret.jwt_secret.arn },
      { name = "HLS_SIGNING_SECRET", valueFrom = aws_secretsmanager_secret.hls_signing_secret.arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["business-logic"].name
        "awslogs-region"        = local.log_opts.region
        "awslogs-stream-prefix" = "api"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "stream_engine" {
  family                   = "${var.project}-stream-engine"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.stream_engine_cpu
  memory                   = var.stream_engine_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.stream_engine_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "go-server"
      image        = "${var.stream_engine_image_url}:latest"
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      environment = [
        { name = "HTTP_LISTEN_ADDR", value = ":8080" },
        { name = "MEDIAMTX_HTTP_URL", value = "http://127.0.0.1:8889" },
        { name = "RABBITMQ_URL", value = local.rabbitmq_amqp_url },
        { name = "RABBITMQ_QUEUE", value = "recordings.ready" },
      ]
      secrets = [
        { name = "STREAM_KEY", valueFrom = aws_secretsmanager_secret.stream_key.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["stream-engine"].name
          "awslogs-region"        = local.log_opts.region
          "awslogs-stream-prefix" = "go-server"
        }
      }
    },
    {
      name      = "mediamtx"
      image     = "${var.mediamtx_image_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 1935, protocol = "tcp" },
        { containerPort = 8889, protocol = "tcp" },
        { containerPort = 8554, protocol = "tcp" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["stream-engine"].name
          "awslogs-region"        = local.log_opts.region
          "awslogs-stream-prefix" = "mediamtx"
        }
      }
    },
  ])
}

resource "aws_ecs_task_definition" "record_service" {
  family                   = "${var.project}-record-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.record_service_cpu
  memory                   = var.record_service_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.record_service_task_role_arn

  container_definitions = jsonencode([{
    name         = "record-service"
    image        = "${var.record_service_image_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 8081, protocol = "tcp" }]
    environment = [
      { name = "HTTP_LISTEN_ADDR", value = ":8081" },
      { name = "DB_HOST", value = var.recordings_db_host },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_NAME", value = var.recordings_db_name },
      { name = "DB_USER", value = "admin" },
      { name = "S3_BUCKET", value = var.recordings_bucket_name },
      { name = "S3_REGION", value = data.aws_region.current.name },
      { name = "RECORDINGS_DIR", value = "/recordings" },
      { name = "RABBITMQ_URL", value = local.rabbitmq_amqp_url },
      { name = "RABBITMQ_QUEUE", value = "recordings.ready" },
    ]
    secrets = [
      { name = "DB_PASSWORD", valueFrom = var.recordings_db_password_secret_arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["record-service"].name
        "awslogs-region"        = local.log_opts.region
        "awslogs-stream-prefix" = "record-service"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "activities" {
  family                   = "${var.project}-activities-ms"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.activities_cpu
  memory                   = var.activities_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.activities_task_role_arn

  container_definitions = jsonencode([{
    name         = "activities-ms"
    image        = "${var.activities_ms_image_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 4000, protocol = "tcp" }]
    environment = [
      { name = "PHX_SERVER", value = "true" },
      { name = "MIX_ENV", value = "prod" },
      { name = "PORT", value = "4000" },
      { name = "PHX_HOST", value = trimprefix(trimprefix(var.public_app_url, "https://"), "http://") },
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = aws_secretsmanager_secret.jwt_secret.arn },
      { name = "SECRET_KEY_BASE", valueFrom = aws_secretsmanager_secret.activities_secret_key_base.arn },
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.activities_database_url.arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["activities-ms"].name
        "awslogs-region"        = local.log_opts.region
        "awslogs-stream-prefix" = "activities"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "recommendations" {
  family                   = "${var.project}-recommendations-ms"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.recommendations_cpu
  memory                   = var.recommendations_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.recommendations_task_role_arn

  container_definitions = jsonencode([{
    name         = "recommendations-ms"
    image        = "${var.recommendations_ms_image_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 8000, protocol = "tcp" }]
    environment = [
      { name = "STREAMS_API_URL", value = "http://business-logic.${local.discovery_namespace}:8082" },
      { name = "ACTIVITIES_API_URL", value = "http://activities.${local.discovery_namespace}:4000" },
      { name = "ALLOWED_ORIGINS", value = jsonencode([var.allowed_origin]) },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["recommendations-ms"].name
        "awslogs-region"        = local.log_opts.region
        "awslogs-stream-prefix" = "recommendations"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project}-blume-wa"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.frontend_task_role_arn

  container_definitions = jsonencode([{
    name         = "blume-wa"
    image        = "${var.blume_wa_image_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment = [
      { name = "API_INTERNAL_URL", value = "http://business-logic.${local.discovery_namespace}:8082" },
      { name = "RECORDINGS_INTERNAL_URL", value = "http://record-service.${local.discovery_namespace}:8081" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["blume-wa"].name
        "awslogs-region"        = local.log_opts.region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}
