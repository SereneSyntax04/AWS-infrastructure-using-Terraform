
output "vpc_id" {
  value = aws_vpc.myvpc.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}

# 0812--------------------------------------------------------------
output "nat_gateway_ids" {
  value     = aws_nat_gateway.nat[*].id
  sensitive = false
}

output "nat_eip_addresses" {
  value     = aws_eip.nat[*].public_ip
  sensitive = false
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}


# 0912-------------------------------------------------------------------------------------------
# ALB entrypoint
output "alb_dns" {
  value = aws_lb.alb.dns_name
}
