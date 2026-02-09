# outputs.tf - Core Lab 1C Outputs Only

output "chewbacca_vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.chewbacca_vpc01.id
}

output "chewbacca_ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.chewbacca_ec201.public_ip
}

output "chewbacca_ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.chewbacca_ec201.id
}

output "chewbacca_rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.chewbacca_rds01.endpoint
}

output "chewbacca_rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.chewbacca_rds01.id
}

output "chewbacca_secret_id" {
  description = "Secrets Manager secret ID"
  value       = aws_secretsmanager_secret.chewbacca_db_secret01.name
}

output "chewbacca_sns_topic_arn" {
  description = "SNS Topic ARN for alerts"
  value       = aws_sns_topic.chewbacca_sns_topic01.arn
}

# --- TGW Outputs (Phase 2) ---
output "shinjuku_tgw_id" {
  value       = aws_ec2_transit_gateway.shinjuku_tgw01.id
  description = "Tokyo Transit Gateway ID"
}

output "shinjuku_peering_attachment_id" {
  value       = aws_ec2_transit_gateway_peering_attachment.shinjuku_to_liberdade_peer01.id
  description = "TGW Peering Attachment ID (needed by São Paulo to accept)"
}