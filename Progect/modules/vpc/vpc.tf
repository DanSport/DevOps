locals {
  # Базові теги
  tags = merge(
    {
      Project = var.vpc_name
    },
    try(var.common_tags, {})
  )

  # Зіставлення AZ → CIDR
  public_map  = zipmap(var.availability_zones, var.public_subnets)
  private_map = zipmap(var.availability_zones, var.private_subnets)

  # Стабільний вибір AZ для одного NAT: беремо першу AZ за алфавітом,
  # яка має публічну підмережу.
  pub_az_sorted = sort(keys(local.public_map))
  nat_az        = local.pub_az_sorted[0]
}

# ---------------- VPC ----------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-vpc"
  })
}

# ---------------- Internet Gateway ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

# ---------------- Subnets ----------------
# Публічні (мають auto-assign public IP)
resource "aws_subnet" "public" {
  for_each                = local.public_map
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-public-${each.key}"
    Tier = "public"
  })
}

# Приватні
resource "aws_subnet" "private" {
  for_each          = local.private_map
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-private-${each.key}"
    Tier = "private"
  })
}

# ---------------- NAT (один на всі AZ) ----------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  # Детермінована публічна сабнета для NAT
  subnet_id  = aws_subnet.public[local.nat_az].id
  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-nat"
  })
}

# ---------------- Route Tables ----------------
# Публічна: 0.0.0.0/0 -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-rt-public"
  })
}

# Прив'язка public RT до всіх публічних сабнетів
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Приватна: 0.0.0.0/0 -> NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-rt-private"
  })
}

# Прив'язка private RT до всіх приватних сабнетів
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# ---------------- (Опційно) Gateway VPC Endpoints ----------------
# Вони безкоштовні та скорочують трафік через NAT для S3/DynamoDB.

resource "aws_vpc_endpoint" "s3" {
  count        = try(var.enable_s3_endpoint, true) ? 1 : 0
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  # Додаємо до приватної таблиці (трафік із приватних сабнетів піде напряму)
  route_table_ids = [aws_route_table.private.id]

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-vpce-s3"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count        = try(var.enable_dynamodb_endpoint, true) ? 1 : 0
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.tags, {
    Name = "${var.vpc_name}-vpce-dynamodb"
  })
}

# Поточний регіон (для endpoint service_name)
data "aws_region" "current" {}

