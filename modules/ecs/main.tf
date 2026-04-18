data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ── Secrets Manager entries (app secrets) ────────────────────────────────────
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project}/jwt-secret"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}

resource "aws_secretsmanager_secret" "hls_signing_secret" {
  name                    = "${var.project}/hls-signing-secret"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "hls_signing_secret" {
  secret_id     = aws_secretsmanager_secret.hls_signing_secret.id
  secret_string = var.hls_signing_secret
}

resource "aws_secretsmanager_secret" "firebase_sa" {
  name                    = "${var.project}/firebase-service-account"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "firebase_sa" {
  secret_id     = aws_secretsmanager_secret.firebase_sa.id
  secret_string = var.firebase_service_account_json
}

resource "aws_secretsmanager_secret" "stream_key" {
  name                    = "${var.project}/stream-key"
  recovery_window_in_days = 0
  tags                    = { Project = var.project }
}

resource "aws_secretsmanager_secret_version" "stream_key" {
  secret_id     = aws_secretsmanager_secret.stream_key.id
  secret_string = var.stream_key
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "business_logic" {
  name              = "/ecs/${var.project}/business-logic"
  retention_in_days = 14
  tags              = { Project = var.project }
}

resource "aws_cloudwatch_log_group" "stream_engine" {
  name              = "/ecs/${var.project}/stream-engine"
  retention_in_days = 14
  tags              = { Project = var.project }
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = var.project

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Project = var.project }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── ALB (internal, fronted by API Gateway) ────────────────────────────────────
resource "aws_lb" "alb" {
  name               = "${var.project}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.private_subnet_ids

  tags = { Project = var.project }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.business_logic.arn
  }
}

# ── ALB Target Groups ─────────────────────────────────────────────────────────
resource "aws_lb_target_group" "business_logic" {
  name        = "${var.project}-bl-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = { Project = var.project }
}

resource "aws_lb_target_group" "stream_engine_http" {
  name        = "${var.project}-se-http-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/stats"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = { Project = var.project }
}

# Route /stream/* to the stream-engine Go server
resource "aws_lb_listener_rule" "stream_engine" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stream_engine_http.arn
  }

  condition {
    path_pattern {
      values = ["/stream/*", "/api/viewer-session", "/api/viewers/*", "/api/stats", "/auth/mediamtx"]
    }
  }
}

# ── NLB (public, for RTMP and WebRTC) ────────────────────────────────────────
resource "aws_lb" "nlb" {
  name               = "${var.project}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  tags = { Project = var.project }
}

resource "aws_lb_target_group" "rtmp" {
  name        = "${var.project}-rtmp-tg"
  port        = 1935
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = { Project = var.project }
}

resource "aws_lb_target_group" "webrtc" {
  name        = "${var.project}-webrtc-tg"
  port        = 8889
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = { Project = var.project }
}

resource "aws_lb_listener" "rtmp" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 1935
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rtmp.arn
  }
}

resource "aws_lb_listener" "webrtc" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8889
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webrtc.arn
  }
}

# ── ECS Task Definition: business-logic ──────────────────────────────────────
resource "aws_ecs_task_definition" "business_logic" {
  family                   = "${var.project}-business-logic"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.business_logic_cpu
  memory                   = var.business_logic_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.business_logic_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.blume_backend_image_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]

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
        { name = "MAIL_PASSWORD", valueFrom = aws_secretsmanager_secret.firebase_sa.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.business_logic.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = { Project = var.project }
}

# ── ECS Task Definition: stream-engine (go-server + mediamtx sidecar) ────────
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
      name      = "go-server"
      image     = "${var.stream_engine_image_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]

      environment = [
        { name = "HTTP_LISTEN_ADDR", value = ":8080" },
        # mediamtx WebRTC API is reachable at localhost since they share a task network
        { name = "MEDIAMTX_HTTP_URL", value = "http://localhost:8889" },
      ]

      secrets = [
        { name = "STREAM_KEY", valueFrom = aws_secretsmanager_secret.stream_key.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.stream_engine.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "go-server"
        }
      }
    },
    {
      name      = "mediamtx"
      image     = "bluenviron/mediamtx:latest"
      essential = true

      portMappings = [
        { containerPort = 1935, protocol = "tcp" },
        { containerPort = 8889, protocol = "tcp" },
      ]

      # Pass config via environment overrides; authHTTPAddress points to
      # the go-server container on localhost (same task network namespace)
      environment = [
        { name = "MTX_LOGLEVEL", value = "info" },
        { name = "MTX_RTMP", value = "yes" },
        { name = "MTX_RTMPADDRESS", value = ":1935" },
        { name = "MTX_WEBRTC", value = "yes" },
        { name = "MTX_WEBRTCADDRESS", value = ":8889" },
        { name = "MTX_HLS", value = "no" },
        { name = "MTX_AUTHMETHOD", value = "http" },
        { name = "MTX_AUTHHTTPADDRESS", value = "http://localhost:8080/auth/mediamtx" },
        { name = "MTX_WEBRTCALLOWORIGINS", value = "*" },
        { name = "MTX_WEBRTCICESERVERS2", value = "url=stun:stun.l.google.com:19302" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.stream_engine.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "mediamtx"
        }
      }
    }
  ])

  tags = { Project = var.project }
}

# ── ECS Services ──────────────────────────────────────────────────────────────
resource "aws_ecs_service" "business_logic" {
  name            = "business-logic"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.business_logic.arn
  desired_count   = var.business_logic_desired_count
  launch_type     = "FARGATE"

  # Pull the latest image on every deployment
  force_new_deployment               = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.business_logic.arn
    container_name   = "api"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]

  tags = { Project = var.project }
}

resource "aws_ecs_service" "stream_engine" {
  name            = "stream-engine"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.stream_engine.arn
  desired_count   = var.stream_engine_desired_count
  launch_type     = "FARGATE"

  force_new_deployment               = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stream_engine_http.arn
    container_name   = "go-server"
    container_port   = 8080
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.rtmp.arn
    container_name   = "mediamtx"
    container_port   = 1935
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webrtc.arn
    container_name   = "mediamtx"
    container_port   = 8889
  }

  depends_on = [
    aws_lb_listener.rtmp,
    aws_lb_listener.webrtc,
    aws_lb_listener_rule.stream_engine,
  ]

  tags = { Project = var.project }
}
