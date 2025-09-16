# Outputs for VPC Configuration

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.superblocks.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.superblocks.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.superblocks.id
}

# Public subnet outputs
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_availability_zones" {
  description = "Availability zones of the public subnets"
  value       = aws_subnet.public[*].availability_zone
}

# Private subnet outputs
output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "Availability zones of the private subnets"
  value       = aws_subnet.private[*].availability_zone
}

# NAT Gateway outputs
output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.superblocks[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

# Security Group outputs
output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}

# Route table outputs
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

# VPC Flow Logs outputs
output "flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = var.enable_flow_logs ? aws_flow_log.superblocks[0].id : null
}

output "flow_log_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_log[0].name : null
}

# Summary outputs for easy reference
output "network_summary" {
  description = "Summary of network configuration"
  value = {
    vpc_id                = aws_vpc.superblocks.id
    vpc_cidr             = aws_vpc.superblocks.cidr_block
    public_subnet_count  = length(aws_subnet.public)
    private_subnet_count = length(aws_subnet.private)
    nat_gateway_count    = length(aws_nat_gateway.superblocks)
    availability_zones   = data.aws_availability_zones.available.names
  }
}

# For Superblocks module consumption
output "superblocks_config" {
  description = "Configuration values for Superblocks deployment"
  value = {
    vpc_id                = aws_vpc.superblocks.id
    lb_subnet_ids         = aws_subnet.public[*].id
    ecs_subnet_ids        = aws_subnet.private[*].id
    alb_security_group_id = aws_security_group.alb.id
    ecs_security_group_id = aws_security_group.ecs.id
  }
}