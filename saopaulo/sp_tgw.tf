############################################
# Transit Gateway — São Paulo Spoke
# São Paulo provides stateless compute. Data stays in Tokyo.
# TGW peering connects São Paulo EC2 → Tokyo RDS.
############################################

# São Paulo Transit Gateway — the spoke endpoint for cross-region routing.
resource "aws_ec2_transit_gateway" "liberdade_tgw01" {
  description = "liberdade-tgw01 (Sao Paulo spoke)"
  tags        = { Name = "liberdade-tgw01" }
}

# Accept the peering request from Tokyo.
# CROSS-STATE REFERENCE: transit_gateway_attachment_id is the peering
# attachment created by Tokyo's TGW peering request. Obtained from
# `cd tokyo/ && terraform output shinjuku_peering_attachment_id`.
# Hardcoded because these are independent Terraform roots.
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "liberdade_accept_peer01" {
  transit_gateway_attachment_id = "tgw-attach-0190087957dfc1d03"
  tags                         = { Name = "liberdade-accept-peer01" }
}

# Attach São Paulo VPC to the local TGW so EC2 traffic can route to Tokyo.
resource "aws_ec2_transit_gateway_vpc_attachment" "liberdade_attach_sp_vpc01" {
  transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  vpc_id             = aws_vpc.chewbacca_vpc01.id
  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  tags               = { Name = "liberdade-attach-sp-vpc01" }
}
