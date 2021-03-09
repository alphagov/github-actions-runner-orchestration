resource "aws_alb" "main" {
  name = "GitHubRunnerOrchestratorALB"

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
      "Name", "GitHubRunnerOrchestratorALB"
    )
  )
}


resource "aws_alb_target_group" "main" {
  name        = "GitHubRunnerOrchestratorALB-TG"
  target_type = "lambda"

  tags = merge(
    var.common_tags,
    map(
      "Name", "GitHubRunnerOrchestratorALB-TG"
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


resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.tls_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }
}
