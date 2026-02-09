############################################
# Locals (naming convention)
############################################
locals {
  name_prefix = var.project_name
}

############################################
# VPC + Internet Gateway
############################################

# The VPC is the isolated network boundary for all Tokyo resources.
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

# Public subnets host internet-facing resources (ALB, NAT Gateway).
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

# Private subnets host compute and database resources with no direct internet access.
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

# NAT Gateway allows private subnets to reach the internet for outbound traffic
# (package updates, API calls) without exposing inbound access.
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

# Private route table sends internet-bound traffic through NAT (outbound only).
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
# Security Groups (EC2 + RDS)
############################################

# EC2 security group: HTTP inbound for the Flask app, all outbound for
# package updates and RDS connectivity.
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

# RDS security group: only allows MySQL traffic from the EC2 security group.
# This SG-to-SG reference is more secure than CIDR-based rules.
resource "aws_security_group" "chewbacca_rds_sg01" {
  name        = "${local.name_prefix}-rds-sg01"
  description = "RDS security group"
  vpc_id      = aws_vpc.chewbacca_vpc01.id

  ingress {
    description     = "MySQL from EC2 app"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.chewbacca_ec2_sg01.id]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg01"
  }
}

############################################
# RDS Subnet Group
############################################

# RDS deploys into private subnets only — no public accessibility.
resource "aws_db_subnet_group" "chewbacca_rds_subnet_group01" {
  name       = "${local.name_prefix}-rds-subnet-group01"
  subnet_ids = aws_subnet.chewbacca_private_subnets[*].id

  tags = {
    Name = "${local.name_prefix}-rds-subnet-group01"
  }
}

############################################
# RDS Instance (MySQL)
############################################

# Primary data store for the application. Deployed in private subnets
# with no public access. São Paulo EC2 reaches this via Transit Gateway.
# NOTE: Single-AZ for lab cost savings. Production would use multi_az = true.
resource "aws_db_instance" "chewbacca_rds01" {
  identifier             = "${local.name_prefix}-rds01"
  engine                 = var.db_engine
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.chewbacca_rds_subnet_group01.name
  vpc_security_group_ids = [aws_security_group.chewbacca_rds_sg01.id]

  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "${local.name_prefix}-rds01"
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

# Secrets Manager access: EC2 reads DB credentials at runtime.
# NOTE: This is the broad managed policy. In São Paulo, this was replaced
# with a least-privilege custom policy scoped to the specific secret ARN
# (see saopaulo/bonus_a.tf). Tokyo retains the managed policy since
# Bonus A was deployed only in São Paulo.
resource "aws_iam_role_policy_attachment" "chewbacca_ec2_secrets_attach" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

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
# EC2 Instance (App Host)
############################################

# Flask application host. Reads DB credentials from Secrets Manager,
# connects to RDS, and serves HTTP on port 80. Bootstrapped via user_data.sh.
resource "aws_instance" "chewbacca_ec201" {
  ami                     = var.ec2_ami_id
  instance_type           = var.ec2_instance_type
  subnet_id               = aws_subnet.chewbacca_public_subnets[0].id
  vpc_security_group_ids  = [aws_security_group.chewbacca_ec2_sg01.id]
  iam_instance_profile    = aws_iam_instance_profile.chewbacca_instance_profile01.name
  user_data               = file("${path.module}/user_data.sh")

  tags = {
    Name = "${local.name_prefix}-ec201"
  }
}

############################################
# Parameter Store (SSM Parameters)
############################################

# Application config stored in SSM Parameter Store for operational
# recovery. Values reference the RDS instance directly.
resource "aws_ssm_parameter" "chewbacca_db_endpoint_param" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_db_instance.chewbacca_rds01.address

  tags = {
    Name = "${local.name_prefix}-param-db-endpoint"
  }
}

resource "aws_ssm_parameter" "chewbacca_db_port_param" {
  name  = "/lab/db/port"
  type  = "String"
  value = tostring(aws_db_instance.chewbacca_rds01.port)

  tags = {
    Name = "${local.name_prefix}-param-db-port"
  }
}

resource "aws_ssm_parameter" "chewbacca_db_name_param" {
  name  = "/lab/db/name"
  type  = "String"
  value = var.db_name

  tags = {
    Name = "${local.name_prefix}-param-db-name"
  }
}

############################################
# Secrets Manager (DB Credentials)
############################################

# DB credentials stored in Secrets Manager — never hardcoded in application code.
# The Flask app retrieves these at runtime via boto3.
resource "aws_secretsmanager_secret" "chewbacca_db_secret01" {
  name = "${local.name_prefix}/rds/mysql"
}

resource "aws_secretsmanager_secret_version" "chewbacca_db_secret_version01" {
  secret_id = aws_secretsmanager_secret.chewbacca_db_secret01.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.chewbacca_rds01.address
    port     = aws_db_instance.chewbacca_rds01.port
    dbname   = var.db_name
  })
}

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
# Triggers SNS notification to the on-call email.
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

# SNS topic for operational alerts. In production, this would
# integrate with PagerDuty, Opsgenie, or Slack.
resource "aws_sns_topic" "chewbacca_sns_topic01" {
  name = "${local.name_prefix}-db-incidents"
}

resource "aws_sns_topic_subscription" "chewbacca_sns_sub01" {
  topic_arn = aws_sns_topic.chewbacca_sns_topic01.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}
