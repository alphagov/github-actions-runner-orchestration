variable "garo_lambda_arn" {
  description = "ARN for the central Lambda"
  type        = list(string)
  default     = [
    "arn:aws:iam::982247885130:role/GARO-Role-prod"
  ]
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "common_tags" {
  default     = {}
  description = "Command resource tags"
  type        = map(string)
}
