############################################
# Transit Gateway Routes — São Paulo
# Routes Tokyo-bound traffic (10.1.0.0/16) through the TGW
# peering corridor so EC2 can reach Tokyo RDS.
############################################

# VPC route: send Tokyo CIDR traffic to the TGW.
resource "aws_route" "liberdade_to_tokyo_route01" {
  route_table_id         = aws_route_table.chewbacca_private_rt01.id
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.liberdade_tgw01.id
}

# TGW static route: forward Tokyo traffic across the peering attachment.
# CROSS-STATE REFERENCE: These IDs were obtained via AWS CLI after the TGW
# peering was established. They cannot be derived from Terraform output
# because the peering attachment and route table belong to separate state files.
# In production, use terraform_remote_state or SSM Parameter Store lookups.
resource "aws_ec2_transit_gateway_route" "liberdade_tgw_to_tokyo01" {
  destination_cidr_block         = "10.1.0.0/16"
  transit_gateway_attachment_id  = "tgw-attach-0190087957dfc1d03"
  transit_gateway_route_table_id = "tgw-rtb-07a7841c4d6b0fc09"
}
