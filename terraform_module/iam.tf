resource "random_integer" "garo_external_id" {
  min = 10000000000000
  max = 100000000000000
}

resource "aws_iam_role" "iam_for_ec2" {
  name = "GitHubRunnerAssumeRole"

  tags = merge(
    var.common_tags,
    map(
      "Name", "GitHubRunnerAssumeRole"
    )
  )

  inline_policy {
    name = "GitHubRunnerAssumeRolePolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "ec2:DescribeSpotInstanceRequests",
            "ec2:RunInstances"
          ]
          Effect   = "Allow"
          Resource = "*"
          "Condition": {
            "StringLike": {
              "aws:ResourceTag/Name": "github-runner-*"
            }
          }
        },
        {
          Action   = [
            "ec2:CreateTags",
            "ec2:DescribeTags",
            "ec2:DescribeImages",
            "ec2:DescribeInstances",
            "ec2:RequestSpotInstances"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }

  assume_role_policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "AWS": var.garo_lambda_arn
          },
          "Condition": {
            "StringEquals": {
              "sts:ExternalId": random_integer.garo_external_id.result
            }
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
  )
}
