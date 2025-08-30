resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.vpc_name }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-igw" }
}

# публічні сабнети по AZ
locals {
  pub_map = zipmap(var.availability_zones, var.public_subnets)
  prv_map = zipmap(var.availability_zones, var.private_subnets)
}

resource "aws_subnet" "public" {
  for_each                = local.pub_map
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.vpc_name}-public-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each          = local.prv_map
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key
  tags              = { Name = "${var.vpc_name}-private-${each.key}" }
}

# один NAT у першій публічній сабнеті (економно)
resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  tags          = { Name = "${var.vpc_name}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}
