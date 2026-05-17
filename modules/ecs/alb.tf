# ── Internet-facing ALB (gateway: routes mirror infrastructure/traefik/dynamic.yml) ──
resource "aws_lb" "alb" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Project = var.project }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project}-wa-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_target_group" "business_logic" {
  name        = "${var.project}-bl-tg"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/actuator/health"
    matcher  = "200-399"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_target_group" "stream_engine" {
  name        = "${var.project}-se-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/api/stats"
    matcher  = "200-399"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_target_group" "record_service" {
  name        = "${var.project}-rec-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/health"
    matcher  = "200-399"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_target_group" "activities" {
  name        = "${var.project}-act-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    matcher  = "200-404"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_target_group" "recommendations" {
  name        = "${var.project}-rec-ms-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/api/v1/health"
    matcher  = "200-399"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_listener_rule" "recordings" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.record_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/recordings", "/api/recordings/*", "/internal/recordings", "/internal/recordings/*", "/internal/streams", "/internal/streams/*"]
    }
  }
}

resource "aws_lb_listener_rule" "streams_next_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    path_pattern {
      values = ["/api/streams", "/api/streams/*"]
    }
  }
}

resource "aws_lb_listener_rule" "stream_engine" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stream_engine.arn
  }

  condition {
    path_pattern {
      values = ["/api/viewer-session", "/api/viewers/*", "/api/stats", "/auth/mediamtx"]
    }
  }
}

resource "aws_lb_listener_rule" "recommendations" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 4

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.recommendations.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1", "/api/v1/*"]
    }
  }
}

resource "aws_lb_listener_rule" "activities_socket" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.activities.arn
  }

  condition {
    path_pattern {
      values = ["/socket", "/socket/*"]
    }
  }
}

resource "aws_lb_listener_rule" "business_logic" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 6

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.business_logic.arn
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }
}

# ── NLB (public RTMP + WebRTC) ────────────────────────────────────────────────
resource "aws_lb" "nlb" {
  name               = "${var.project}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "rtmp" {
  name        = "${var.project}-rtmp-tg"
  port        = 1935
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "TCP"
    interval = 10
  }
}

resource "aws_lb_target_group" "webrtc" {
  name        = "${var.project}-webrtc-tg"
  port        = 8889
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "TCP"
    interval = 10
  }
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
