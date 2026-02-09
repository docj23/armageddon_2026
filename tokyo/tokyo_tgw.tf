############################################
# Transit Gateway — Tokyo Hub
# Tokyo is the data authority region (RDS + Secrets Manager).
# TGW peering connects Tokyo ↔ São Paulo for cross-region
# database access while maintaining data residency.
############################################

# Tokyo Transit Gateway — the hub for all cross-region routing.
resource "aws_ec2_transit_gateway" "shinjuku_tgw01" {
  description = "shinjuku-tgw01 (Tokyo hub)"
  tags        = { Name = "shinjuku-tgw01" }
}

# Attach the Tokyo VPC to the TGW so RDS is reachable via the corridor.
resource "aws_ec2_transit_gateway_vpc_attachment" "shinjuku_attach_tokyo_vpc01" {
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  vpc_id             = aws_vpc.chewbacca_vpc01.id
  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  tags               = { Name = "shinjuku-attach-tokyo-vpc01" }
}

# Peering request from Tokyo → São Paulo.
# CROSS-STATE REFERENCE: peer_transit_gateway_id is the São Paulo TGW ID,
# obtained from `cd saopaulo/ && terraform output liberdade_tgw_id`.
# In production, use terraform_remote_state or SSM Parameter Store.
# Hardcoded here because Tokyo and São Paulo are independent Terraform
# roots with separate state files.
resource "aws_ec2_transit_gateway_peering_attachment" "shinjuku_to_liberdade_peer01" {
  transit_gateway_id      = aws_ec2_transit_gateway.shinjuku_tgw01.id
  peer_region             = "sa-east-1"
  peer_transit_gateway_id = "tgw-04c6d796613b8285f"
  tags                    = { Name = "shinjuku-to-liberdade-peer01" }
}
