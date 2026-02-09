############################################
# Bonus A - Data + Locals
############################################

# Explanation: Chewbacca wants to know "who am I in this galaxy?" so ARNs can be scoped properly.
data "aws_caller_identity" "chewbacca_self01" {}

# Explanation: Region matters—hyperspace lanes change per sector.
data "aws_region" "chewbacca_region01" {}

locals {
  # Explanation: Name prefix is the roar that echoes through every tag.
  chewbacca_prefix = var.project_name

  # São Paulo EC2 reads the secret from TOKYO (ap-northeast-1), not locally.
  # The secret name is shinjuku/rds/mysql and it lives in Tokyo.
  chewbacca_secret_arn_guess = "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.chewbacca_self01.account_id}:secret:shinjuku/rds/mysql*"
}

############################################
# Security Group for VPC Interface Endpoints
############################################

# Explanation: Even endpoints need guards—Chewbacca posts a Wookiee at every airlock.
# Interface endpoints receive traffic on port 443 (HTTPS). EC2 must be allowed to talk to them.
resource "aws_security_group" "chewbacca_vpce_sg01" {
  name        = "${local.chewbacca_prefix}-vpce-sg01"
  description = "SG for VPC Interface Endpoints"
  vpc_id      = aws_vpc.chewbacca_vpc01.id

  # Allow inbound HTTPS from the EC2 security group
  ingress {
    description     = "HTTPS from EC2 SG"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.chewbacca_ec2_sg01.id]
  }

  # Allow all outbound (endpoints need to respond)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-sg01"
  }
}

############################################
# VPC Endpoint - S3 (Gateway)
############################################

# Explanation: S3 is the supply depot—without this, your private world starves (updates, artifacts, logs).
# Gateway endpoints are FREE and don't use ENIs — they add a route to the route table.
resource "aws_vpc_endpoint" "chewbacca_vpce_s3_gw01" {
  vpc_id            = aws_vpc.chewbacca_vpc01.id
  service_name      = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.chewbacca_private_rt01.id
  ]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-s3-gw01"
  }
}

############################################
# VPC Endpoints - SSM (Interface)
############################################

# Explanation: SSM is your Force choke—remote control without SSH, and nobody sees your keys.
# These three endpoints together enable SSM Session Manager for private EC2 instances.
resource "aws_vpc_endpoint" "chewbacca_vpce_ssm01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-ssm01"
  }
}

# Explanation: ec2messages is the Wookiee messenger—SSM sessions won't work without it.
resource "aws_vpc_endpoint" "chewbacca_vpce_ec2messages01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-ec2messages01"
  }
}

# Explanation: ssmmessages is the holonet channel—Session Manager needs it to talk back.
resource "aws_vpc_endpoint" "chewbacca_vpce_ssmmessages01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-ssmmessages01"
  }
}

############################################
# VPC Endpoint - CloudWatch Logs (Interface)
############################################

# Explanation: CloudWatch Logs is the ship's black box—Chewbacca wants crash data, always.
resource "aws_vpc_endpoint" "chewbacca_vpce_logs01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-logs01"
  }
}

############################################
# VPC Endpoint - Secrets Manager (Interface)
############################################

# Explanation: Secrets Manager is the locked vault—Chewbacca doesn't put passwords on sticky notes.
# NOTE: This endpoint is for LOCAL API calls. São Paulo EC2 reads the Tokyo secret
# via the Secrets Manager API (specifying region=ap-northeast-1 in the boto3 client).
# The API call itself goes over the internet/NAT, NOT through this endpoint.
# This endpoint is still useful for any LOCAL secrets if added later.
resource "aws_vpc_endpoint" "chewbacca_vpce_secrets01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-secrets01"
  }
}

############################################
# Optional: VPC Endpoint - KMS (Interface)
############################################

# Explanation: KMS is the encryption kyber crystal—Chewbacca prefers locked doors AND locked safes.
resource "aws_vpc_endpoint" "chewbacca_vpce_kms01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-kms01"
  }
}

############################################
# Least-Privilege IAM (BONUS A)
############################################

# NOTE: The professor's template includes SSM Parameter Store read policies.
# São Paulo has NO local SSM parameters (they're all in Tokyo).
# We include the policy anyway for completeness and future use,
# but scoped to the local region.

# Explanation: Chewbacca doesn't hand out the Falcon keys—this policy scopes reads to your lab paths only.
resource "aws_iam_policy" "chewbacca_leastpriv_read_params01" {
  name        = "${local.chewbacca_prefix}-lp-ssm-read01"
  description = "Least-privilege read for SSM Parameter Store under /lab/db/*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLabDbParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.chewbacca_region01.name}:${data.aws_caller_identity.chewbacca_self01.account_id}:parameter/lab/db/*"
        ]
      }
    ]
  })
}

# Explanation: Chewbacca only opens *this* vault—GetSecretValue for only your secret (not the whole planet).
# IMPORTANT: This points to Tokyo's secret (shinjuku/rds/mysql in ap-northeast-1)
# because São Paulo EC2 reads credentials from Tokyo, not locally.
resource "aws_iam_policy" "chewbacca_leastpriv_read_secret01" {
  name        = "${local.chewbacca_prefix}-lp-secrets-read01"
  description = "Least-privilege read for the lab DB secret (Tokyo)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyLabSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.chewbacca_secret_arn_guess
      }
    ]
  })
}

# Explanation: When the Falcon logs scream, this lets Chewbacca ship logs to CloudWatch.
resource "aws_iam_policy" "chewbacca_leastpriv_cwlogs01" {
  name        = "${local.chewbacca_prefix}-lp-cwlogs01"
  description = "Least-privilege CloudWatch Logs write for the app log group"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.chewbacca_log_group01.arn}:*"
        ]
      }
    ]
  })
}

# Explanation: Attach the scoped policies—Chewbacca loves power, but only the safe kind.
resource "aws_iam_role_policy_attachment" "chewbacca_attach_lp_params01" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = aws_iam_policy.chewbacca_leastpriv_read_params01.arn
}

resource "aws_iam_role_policy_attachment" "chewbacca_attach_lp_secret01" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = aws_iam_policy.chewbacca_leastpriv_read_secret01.arn
}

resource "aws_iam_role_policy_attachment" "chewbacca_attach_lp_cwlogs01" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = aws_iam_policy.chewbacca_leastpriv_cwlogs01.arn
}
