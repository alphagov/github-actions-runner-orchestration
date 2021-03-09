resource "aws_kms_key" "a" {
  description              = "KMS key for GitHub token handling"
  deletion_window_in_days  = 10
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "RSA_4096"

  policy = <<EOT
  {
    "Id": "key-consolepolicy-3",
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "Enable IAM User Permissions",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::241911176277:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Sid": "Allow use of the key",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${aws_iam_role.iam_for_lambda.arn}"
        },
        "Action": [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:DescribeKey",
          "kms:Decrypt"
        ],
        "Resource": "*"
      }
    ]
  }
  EOT
}
