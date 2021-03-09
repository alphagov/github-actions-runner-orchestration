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
            "ec2:CreateTags",
            "ec2:DescribeSpotInstanceRequests",
            "ec2:DescribeTags",
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
            "ec2:DescribeSpotInstanceRequests",
            "ec2:DescribeTags",
            "ec2:DescribeImages",
            "ec2:RunInstances",
            "ec2:DescribeInstances",
            "ec2:RequestSpotInstances",
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
        "AWS": "${aws_iam_role.iam_for_lambda.arn}"
      },
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${var.garo_external_id}"
        }
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
