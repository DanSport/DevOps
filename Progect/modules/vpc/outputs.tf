output "vpc_id" {
  description = "ID створеної VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Список ID публічних сабнетів"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "Список ID приватних сабнетів"
  value       = [for s in aws_subnet.private : s.id]
}

output "internet_gateway_id" {
  description = "ID Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "ID NAT Gateway (єдиний)"
  value       = aws_nat_gateway.nat.id
}

output "nat_eip" {
  description = "Публічна IP-адреса NAT (Elastic IP)"
  value       = aws_eip.nat.public_ip
}
