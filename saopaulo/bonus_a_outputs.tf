# ============================================
# Bonus A Outputs - VPC Endpoints
# ============================================

output "chewbacca_vpce_ssm_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_ssm01.id
}

output "chewbacca_vpce_logs_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_logs01.id
}

output "chewbacca_vpce_secrets_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_secrets01.id
}

output "chewbacca_vpce_s3_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_s3_gw01.id
}
