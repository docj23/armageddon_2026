# ============================================
# São Paulo Outputs
# ============================================

output "chewbacca_vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.chewbacca_vpc01.id
}

output "chewbacca_ec2_private_ip" {
  description = "Private IP of EC2 instance (no public IP)"
  value       = aws_instance.chewbacca_ec201.private_ip
}

output "chewbacca_alb_dns_name" {
  description = "ALB DNS name (public HTTPS entry point)"
  value       = aws_lb.chewbacca_alb01.dns_name
}

output "chewbacca_ec2_instance_id" {
  description = "EC2 Instance ID (use with SSM Session Manager)"
  value       = aws_instance.chewbacca_ec201.id
}

output "chewbacca_sns_topic_arn" {
  description = "SNS Topic ARN for alerts"
  value       = aws_sns_topic.chewbacca_sns_topic01.arn
}

# --- Transit Gateway ---
output "liberdade_tgw_id" {
  description = "São Paulo Transit Gateway ID (needed by Tokyo for peering)"
  value       = aws_ec2_transit_gateway.liberdade_tgw01.id
}
