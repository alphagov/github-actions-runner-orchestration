resource "aws_vpc" "main" {
  cidr_block = "10.50.0.0/16"

  enable_dns_support="false"
  enable_dns_hostnames="false"

  tags = merge(
    var.common_tags,
    map(
      "Name", "GitHubRunnerOrchestrator"
    )
  )
}

data "aws_route_table" "selected" {
  vpc_id     = aws_vpc.main.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    map(
      "Name", "Main"
    )
  )
}

resource "aws_route" "route" {
  route_table_id            = data.aws_route_table.selected.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gw.id
}

resource "aws_subnet" "main-a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.50.1.0/24"
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = "false"

  tags = merge(
    var.common_tags,
    map(
      "Name", "main-2a"
    )
  )
}

resource "aws_subnet" "main-b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.50.2.0/24"
  availability_zone = "eu-west-2b"
  map_public_ip_on_launch = "false"

  tags = merge(
    var.common_tags,
    map(
      "Name", "main-2b"
    )
  )
}

resource "aws_subnet" "main-c" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.50.3.0/24"
  availability_zone = "eu-west-2c"
  map_public_ip_on_launch = "false"

  tags = merge(
    var.common_tags,
    map(
      "Name", "main-2c"
    )
  )
}
