resource "aws_iam_instance_profile" "profile_for_instances" {
  name = "GitHubRunnerInstanceRole"
  role = aws_iam_role.role_for_instances.name
}

resource "aws_iam_role" "role_for_instances" {
  name = "GitHubRunnerInstanceRole"

  tags = merge(
    var.common_tags,
    map(
      "Name", "GitHubRunnerInstanceRole"
    )
  )

  inline_policy {
    name = "GitHubRunnerAssumeRolePolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath",
            ],
            "Resource": "arn:aws:ssm:${var.region}:*:parameter/github/runner/pat"
        },
        {
          Action   = [
            "ec2:CreateTags",
            "ec2:DescribeTags",
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
          "Effect": "Allow",
          "Principal": { "Service": "ec2.amazonaws.com"},
          "Action": "sts:AssumeRole"
        }
      ]
    }
  )
}
