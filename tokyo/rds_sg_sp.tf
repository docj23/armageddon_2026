############################################
# RDS Security Group — Cross-Region Access from São Paulo
# Allows São Paulo EC2 (10.2.0.0/16) to reach Tokyo RDS on port 3306
# via the Transit Gateway peering corridor.
############################################

resource "aws_security_group_rule" "shinjuku_rds_ingress_from_liberdade01" {
  type              = "ingress"
  security_group_id = aws_security_group.chewbacca_rds_sg01.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.2.0.0/16"]
}
