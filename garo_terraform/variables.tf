variable "common_tags" {
  default     = {}
  description = "Command resource tags"
  type        = map(string)
}

variable "tls_cert_arn" {
  description = "ARN for the TLS cert for the ALB"
  type        = string
  default     = "arn:aws:acm:eu-west-2:982247885130:certificate/f2772ecf-24c1-46af-afb2-c34e8d01393c"
}

variable "hostname" {
  type = map
  default = {
    dev     = "dev.co-cdio-garo.digital"
    staging = "staging.co-cdio-garo.digital"
    prod    = "prod.co-cdio-garo.digital"
  }
}

variable "vpc_subnet" {
  type = map
  default = {
    dev     = "10.50.0.0/16"
    staging = "10.60.0.0/16"
    prod    = "10.70.0.0/16"
  }
}

variable "vpc_subnet_a" {
  type = map
  default = {
    dev     = "10.50.1.0/24"
    staging = "10.60.1.0/24"
    prod    = "10.70.1.0/24"
  }
}

variable "vpc_subnet_b" {
  type = map
  default = {
    dev     = "10.50.2.0/24"
    staging = "10.60.2.0/24"
    prod    = "10.70.2.0/24"
  }
}

variable "vpc_subnet_c" {
  type = map
  default = {
    dev     = "10.50.3.0/24"
    staging = "10.60.3.0/24"
    prod    = "10.70.3.0/24"
  }
}
