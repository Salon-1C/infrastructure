locals {
  service_discovery = {
    business-logic  = "business-logic"
    stream-engine   = "stream-engine"
    record-service  = "record-service"
    activities      = "activities"
    recommendations = "recommendations"
    blume-wa        = "blume-wa"
  }
}

resource "aws_service_discovery_service" "app" {
  for_each = local.service_discovery

  name = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "business_logic" {
  name            = "business-logic"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.business_logic.arn
  desired_count   = var.business_logic_desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.business_logic.arn
    container_name   = "api"
    container_port   = 8082
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app["business-logic"].arn
  }

  depends_on = [aws_lb_listener_rule.business_logic]
}

resource "aws_ecs_service" "stream_engine" {
  name            = "stream-engine"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.stream_engine.arn
  desired_count   = var.stream_engine_desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stream_engine.arn
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

  service_registries {
    registry_arn = aws_service_discovery_service.app["stream-engine"].arn
  }

  depends_on = [
    aws_lb_listener.rtmp,
    aws_lb_listener.webrtc,
    aws_lb_listener_rule.stream_engine,
  ]
}

resource "aws_ecs_service" "record_service" {
  name            = "record-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.record_service.arn
  desired_count   = var.record_service_desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.record_service.arn
    container_name   = "record-service"
    container_port   = 8081
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app["record-service"].arn
  }

  depends_on = [aws_lb_listener_rule.recordings]
}

resource "aws_ecs_service" "activities" {
  name            = "activities-ms"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.activities.arn
  desired_count   = var.activities_desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.activities.arn
    container_name   = "activities-ms"
    container_port   = 4000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app["activities"].arn
  }

  depends_on = [aws_lb_listener_rule.activities_socket]
}

resource "aws_ecs_service" "recommendations" {
  name            = "recommendations-ms"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.recommendations.arn
  desired_count   = var.recommendations_desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.recommendations.arn
    container_name   = "recommendations-ms"
    container_port   = 8000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app["recommendations"].arn
  }

  depends_on = [aws_lb_listener_rule.recommendations]
}

resource "aws_ecs_service" "frontend" {
  name            = "blume-wa"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "blume-wa"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app["blume-wa"].arn
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "${var.project}-rabbitmq"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "rabbitmq"
    image     = "rabbitmq:3.13-management"
    essential = true
    portMappings = [
      { containerPort = 5672, protocol = "tcp" },
    ]
    environment = [
      { name = "RABBITMQ_DEFAULT_USER", value = "guest" },
      { name = "RABBITMQ_DEFAULT_PASS", value = "guest" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.rabbitmq.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "rabbitmq"
      }
    }
  }])
}

resource "aws_service_discovery_service" "rabbitmq" {
  name = "rabbitmq"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "rabbitmq" {
  name            = "rabbitmq"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq.arn
  }
}
