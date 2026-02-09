############################################
# Transit Gateway Routes — Tokyo
# Routes São Paulo-bound traffic (10.2.0.0/16) through the TGW
# peering corridor so RDS responses reach São Paulo EC2.
############################################

# VPC route: send São Paulo CIDR traffic to the TGW.
resource "aws_route" "shinjuku_to_sp_route01" {
  route_table_id         = aws_route_table.chewbacca_private_rt01.id
  destination_cidr_block = "10.2.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.shinjuku_tgw01.id
}

# TGW static route: forward São Paulo traffic across the peering attachment.
# CROSS-STATE REFERENCE: These IDs were obtained via AWS CLI after the TGW
# peering was established. They cannot be derived from Terraform output
# because the peering attachment and route table belong to separate state files.
# In production, use terraform_remote_state or SSM Parameter Store lookups.
resource "aws_ec2_transit_gateway_route" "shinjuku_tgw_to_sp01" {
  destination_cidr_block         = "10.2.0.0/16"
  transit_gateway_attachment_id  = "tgw-attach-0190087957dfc1d03"
  transit_gateway_route_table_id = "tgw-rtb-08fe028e2af07d22d"
}
