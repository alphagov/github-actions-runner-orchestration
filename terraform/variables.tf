variable "common_tags" {
  default     = {}
  description = "Command resource tags"
  type        = map(string)
}

variable "tls_cert_arn" {
  description = "ARN for the TLS cert for the ALB"
  type        = string
}

variable "garo_external_id" {
  description = "External ID for the assume role in the GARO account"
  type        = string
}
