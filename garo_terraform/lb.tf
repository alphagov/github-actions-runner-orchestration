resource "aws_alb" "main" {
  name = "GARO-ALB-${terraform.workspace}"

  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = [
    aws_subnet.main-a.id,
    aws_subnet.main-b.id,
    aws_subnet.main-c.id,
  ]

  tags = merge(
    var.common_tags,
    map(
      "Name", "GARO-ALB-${terraform.workspace}"
    )
  )
}


resource "aws_alb_target_group" "main" {
  name        = "GARO-ALB-TG-${terraform.workspace}"
  target_type = "lambda"

  tags = merge(
    var.common_tags,
    map(
      "Name", "GARO-ALB-TG-${terraform.workspace}"
    )
  )
}


resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator_lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_alb_target_group.main.arn
}


resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_alb_target_group.main.arn
  target_id        = aws_lambda_function.orchestrator_lambda.arn
  depends_on       = [aws_lambda_permission.with_lb]
}


resource "aws_lb_listener_rule" "lambda" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/start", "/status", "/state"]
    }
  }

  condition {
    host_header {
      values = [var.hostname[terraform.workspace]]
    }
  }
}


resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.tls_cert_arn

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      host        = "github.com"
      path        = "/alphagov/github-actions-runner-orchestration"
      status_code = "HTTP_302"
    }
  }
}
