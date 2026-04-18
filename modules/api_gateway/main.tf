# ── VPC Link (connects API Gateway to the internal ALB) ───────────────────────
resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.project}-vpc-link"
  security_group_ids = [var.alb_sg_id]
  subnet_ids         = var.private_subnet_ids

  tags = { Project = var.project }
}

# ── HTTP API ──────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Requested-With"]
    max_age       = 300
  }

  tags = { Project = var.project }
}

# ── Integration: HTTP_PROXY → internal ALB ────────────────────────────────────
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.alb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.this.id
}

# ── Default catch-all route ───────────────────────────────────────────────────
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# ── Auto-deployed stage ($default) ───────────────────────────────────────────
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
  }

  tags = { Project = var.project }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.project}"
  retention_in_days = 14
  tags              = { Project = var.project }
}
