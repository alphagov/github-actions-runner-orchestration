resource "aws_iam_role" "iam_for_lambda" {
  name = "GitHubRunnerOrchestratorRole"

  tags = merge(
    var.common_tags,
    map(
      "Name", "GitHubRunnerOrchestratorRole"
    )
  )

  inline_policy {
    name = "GitHubRunnerOrchestratorRolePolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "sts:AssumeRole"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:iam::*:role/GitHubRunnerAssumeRole"
        },
        {
          Action   = [
            "iam:PassRole",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "orchestrator_lambda" {
  filename      = "../.build/lambda.zip"
  function_name = "GitHubRunnerOrchestrator"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_handler.lambda_handler"
  source_code_hash = filebase64sha256("../.build/lambda.zip")

  runtime = "python3.8"
  memory_size = "256"
  timeout = "60"

  environment {
    variables = {
      DEBUG = "0"
    }
  }

  tags = merge(
    var.common_tags,
    map(
      "Name", "GitHubRunnerOrchestrator"
    )
  )
}
