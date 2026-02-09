############################################
# Locals (naming convention)
############################################
locals {
  name_prefix = var.project_name
}

############################################
# VPC + Internet Gateway
############################################

# The VPC is the isolated network boundary for all São Paulo resources.
resource "aws_vpc" "chewbacca_vpc01" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc01"
  }
}

# Internet Gateway provides public internet access to public subnets.
resource "aws_internet_gateway" "chewbacca_igw01" {
  vpc_id = aws_vpc.chewbacca_vpc01.id

  tags = {
    Name = "${local.name_prefix}-igw01"
  }
}

############################################
# Subnets (Public + Private)
############################################

# Public subnets host the ALB (internet-facing entry point).
resource "aws_subnet" "chewbacca_public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.chewbacca_vpc01.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet0${count.index + 1}"
  }
}

# Private subnets host EC2 compute. No public IP, no direct internet access.
# EC2 reaches AWS APIs via VPC Endpoints (see bonus_a.tf) and Tokyo RDS
# via Transit Gateway (see sp_tgw.tf).
resource "aws_subnet" "chewbacca_private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.chewbacca_vpc01.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${local.name_prefix}-private-subnet0${count.index + 1}"
  }
}

############################################
# NAT Gateway + EIP
############################################

# Elastic IP gives the NAT Gateway a stable public address.
resource "aws_eip" "chewbacca_nat_eip01" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip01"
  }
}

# NAT Gateway allows private subnets to reach the internet for outbound
# traffic. With VPC Endpoints deployed (bonus_a.tf), NAT is only needed
# for non-AWS destinations (OS package repos, external APIs).
resource "aws_nat_gateway" "chewbacca_nat01" {
  allocation_id = aws_eip.chewbacca_nat_eip01.id
  subnet_id     = aws_subnet.chewbacca_public_subnets[0].id

  tags = {
    Name = "${local.name_prefix}-nat01"
  }

  depends_on = [aws_internet_gateway.chewbacca_igw01]
}

############################################
# Routing (Public + Private Route Tables)
############################################

# Public route table sends internet-bound traffic through the IGW.
resource "aws_route_table" "chewbacca_public_rt01" {
  vpc_id = aws_vpc.chewbacca_vpc01.id

  tags = {
    Name = "${local.name_prefix}-public-rt01"
  }
}

resource "aws_route" "chewbacca_public_default_route" {
  route_table_id         = aws_route_table.chewbacca_public_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.chewbacca_igw01.id
}

resource "aws_route_table_association" "chewbacca_public_rta" {
  count          = length(aws_subnet.chewbacca_public_subnets)
  subnet_id      = aws_subnet.chewbacca_public_subnets[count.index].id
  route_table_id = aws_route_table.chewbacca_public_rt01.id
}

# Private route table: internet via NAT, Tokyo via TGW (see sp_tg_routes.tf).
resource "aws_route_table" "chewbacca_private_rt01" {
  vpc_id = aws_vpc.chewbacca_vpc01.id

  tags = {
    Name = "${local.name_prefix}-private-rt01"
  }
}

resource "aws_route" "chewbacca_private_default_route" {
  route_table_id         = aws_route_table.chewbacca_private_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.chewbacca_nat01.id
}

resource "aws_route_table_association" "chewbacca_private_rta" {
  count          = length(aws_subnet.chewbacca_private_subnets)
  subnet_id      = aws_subnet.chewbacca_private_subnets[count.index].id
  route_table_id = aws_route_table.chewbacca_private_rt01.id
}

############################################
# Security Group (EC2)
############################################

# EC2 security group: HTTP inbound for the Flask app, all outbound
# for package updates, AWS API calls, and RDS connectivity via TGW.
# NOTE: No RDS security group in São Paulo — database lives in Tokyo.
resource "aws_security_group" "chewbacca_ec2_sg01" {
  name        = "${local.name_prefix}-ec2-sg01"
  description = "EC2 app security group"
  vpc_id      = aws_vpc.chewbacca_vpc01.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ec2-sg01"
  }
}

############################################
# IAM Role + Instance Profile for EC2
############################################

# EC2 uses an IAM role (not static keys) for AWS API access.
resource "aws_iam_role" "chewbacca_ec2_role01" {
  name = "${local.name_prefix}-ec2-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# SSM Managed Instance Core: enables SSM Session Manager for secure
# shell access without SSH keys or open inbound ports.
resource "aws_iam_role_policy_attachment" "chewbacca_ec2_ssm_attach" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# NOTE: The broad SecretsManagerReadWrite policy was removed and replaced
# with least-privilege custom policies in bonus_a.tf that scope access
# to only the specific Tokyo secret (shinjuku/rds/mysql).

# CloudWatch Agent: ships application logs and metrics to CloudWatch.
resource "aws_iam_role_policy_attachment" "chewbacca_ec2_cw_attach" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile binds the IAM role to the EC2 instance.
resource "aws_iam_instance_profile" "chewbacca_instance_profile01" {
  name = "${local.name_prefix}-instance-profile01"
  role = aws_iam_role.chewbacca_ec2_role01.name
}

############################################
# EC2 Instance (Stateless Compute)
############################################

# Flask application host in a PRIVATE subnet (no public IP).
# Reads DB credentials from Tokyo Secrets Manager via cross-region API call.
# Connects to Tokyo RDS via Transit Gateway.
# Administrative access via SSM Session Manager (no SSH).
resource "aws_instance" "chewbacca_ec201" {
  ami                     = var.ec2_ami_id
  instance_type           = var.ec2_instance_type
  subnet_id               = aws_subnet.chewbacca_private_subnets[0].id
  vpc_security_group_ids  = [aws_security_group.chewbacca_ec2_sg01.id]
  iam_instance_profile    = aws_iam_instance_profile.chewbacca_instance_profile01.name
  user_data               = file("${path.module}/user_data.sh")

  tags = {
    Name = "${local.name_prefix}-ec201"
  }
}

# NOTE: No RDS, Parameter Store, or Secrets Manager resources in São Paulo.
# Database and credentials live in Tokyo (ap-northeast-1) for APPI data
# residency compliance. São Paulo EC2 accesses Tokyo RDS via Transit Gateway
# and reads the Tokyo secret via cross-region Secrets Manager API call.

############################################
# CloudWatch Logs (Log Group)
############################################

# Centralized log group for the application. Retention set to 7 days for lab.
resource "aws_cloudwatch_log_group" "chewbacca_log_group01" {
  name              = "/aws/ec2/${local.name_prefix}-rds-app"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-log-group01"
  }
}

############################################
# CloudWatch Alarm (DB Connection Failures)
############################################

# Fires when DBConnectionErrors >= 3 in a 5-minute period.
resource "aws_cloudwatch_metric_alarm" "chewbacca_db_alarm01" {
  alarm_name          = "${local.name_prefix}-db-connection-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DBConnectionErrors"
  namespace           = "Lab/RDSApp"
  period              = 300
  statistic           = "Sum"
  threshold           = 3

  alarm_actions = [aws_sns_topic.chewbacca_sns_topic01.arn]

  tags = {
    Name = "${local.name_prefix}-alarm-db-fail"
  }
}

############################################
# SNS (Incident Notification)
############################################

# SNS topic for operational alerts.
resource "aws_sns_topic" "chewbacca_sns_topic01" {
  name = "${local.name_prefix}-db-incidents"
}

resource "aws_sns_topic_subscription" "chewbacca_sns_sub01" {
  topic_arn = aws_sns_topic.chewbacca_sns_topic01.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}
