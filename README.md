# Armageddon 2026 — Multi-Region AWS Infrastructure (Terraform)

A production-grade, multi-region AWS architecture deployed entirely with Terraform. Two independent regions — **Tokyo** (data authority) and **São Paulo** (stateless compute) — connected via Transit Gateway peering, with APPI-compliant data residency controls.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        INTERNET                                     │
│                           │                                         │
│              ┌────────────┴────────────┐                            │
│              │     Route53 / ACM       │                            │
│              │  cigarsrmypassion.click  │                            │
│              └────────────┬────────────┘                            │
│                           │                                         │
│   ┌───────────────────────┼───────────────────────┐                 │
│   │  SÃO PAULO (sa-east-1)│  TOKYO (ap-northeast-1)│                │
│   │                       │                        │                │
│   │  ┌─────┐   ┌───────┐ │  ┌───────┐  ┌───────┐  │                │
│   │  │ WAF │──▶│  ALB  │ │  │  ALB  │──│  WAF  │  │                │
│   │  └─────┘   └───┬───┘ │  └───┬───┘  └───────┘  │                │
│   │                │      │      │                  │                │
│   │         ┌──────┴──┐   │  ┌───┴────┐             │                │
│   │         │   EC2   │   │  │  EC2   │             │                │
│   │         │(private)│   │  │(public)│             │                │
│   │         └────┬────┘   │  └────────┘             │                │
│   │              │        │                         │                │
│   │    ┌─────────┴──┐     │  ┌──────────────┐       │                │
│   │    │VPC Endpoints│    │  │  RDS (MySQL)  │       │                │
│   │    │ SSM, S3,    │    │  │  (private)    │       │                │
│   │    │ Logs, KMS,  │    │  ├──────────────┤       │                │
│   │    │ Secrets     │    │  │Secrets Manager│       │                │
│   │    └─────────────┘    │  │Parameter Store│       │                │
│   │                       │  └──────────────┘       │                │
│   │   ┌─────────┐        │       ┌─────────┐        │                │
│   │   │  TGW    │◄═══════╪══════▶│  TGW    │        │                │
│   │   │(spoke)  │ peering│       │ (hub)   │        │                │
│   │   └─────────┘        │       └─────────┘        │                │
│   └───────────────────────┴────────────────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
```

## What This Project Demonstrates

| Skill Area | Implementation |
|---|---|
| **Infrastructure as Code** | 100% Terraform — no console clicks. ~109 resources across 2 regions. |
| **Multi-Region Architecture** | Transit Gateway peering between Tokyo and São Paulo with static routes. |
| **Data Residency Compliance** | RDS and Secrets Manager in Tokyo only (APPI compliance). São Paulo has stateless compute only. |
| **Zero-Trust Networking** | Private EC2 (no public IP), VPC Endpoints for AWS API access, SSM Session Manager for admin access (no SSH). |
| **TLS / Certificate Management** | ACM certificates with DNS validation via Route53. TLS 1.3 policy on ALB. HTTP → HTTPS redirect. |
| **WAF** | AWS Managed Rules (Common Rule Set) attached to ALB. CloudWatch metrics enabled. |
| **Least-Privilege IAM** | Custom IAM policies scoped to specific secret ARNs and log groups. Replaced broad managed policies. |
| **Observability** | CloudWatch dashboards, ALB 5xx alarms, DB connection failure alarms, SNS incident notifications. |
| **Incident Response** | SNS → email alerting pipeline. CloudWatch alarms for DB and ALB failures. |
| **Security Groups** | SG-to-SG references (ALB→EC2, EC2→RDS). No wildcard CIDR rules for internal traffic. |

## Tech Stack

- **IaC:** Terraform (~30 `.tf` files across 2 roots)
- **Cloud:** AWS (25+ services)
- **Compute:** EC2 (Amazon Linux 2023), Application Load Balancer
- **Database:** RDS MySQL (private subnet, not publicly accessible)
- **Networking:** VPC, Transit Gateway, VPC Endpoints, NAT Gateway, Route53
- **Security:** WAFv2, ACM, IAM (custom least-privilege policies), Security Groups
- **Secrets:** Secrets Manager, SSM Parameter Store
- **Monitoring:** CloudWatch (Logs, Alarms, Dashboards), SNS
- **App:** Python Flask (bootstrapped via EC2 user_data.sh)
- **Admin Access:** SSM Session Manager (no SSH keys, no open ports)

## AWS Services Used

EC2, RDS, VPC, ALB, WAFv2, ACM, Route53, Transit Gateway, VPC Endpoints (7 types), IAM, Secrets Manager, SSM Parameter Store, SSM Session Manager, CloudWatch Logs, CloudWatch Alarms, CloudWatch Dashboards, SNS, NAT Gateway, Internet Gateway, S3 (gateway endpoint), KMS (endpoint), Security Groups, Network ACLs, CloudTrail

## Deployment Architecture

This project uses **two independent Terraform roots** (one per region) — the industry-standard pattern for multi-region deployments. Each root has its own state file, provider configuration, and can be deployed/destroyed independently.

### Deployment Order

```
1. cd saopaulo/ → terraform apply     # Creates VPC, TGW, EC2, ALB
2. cd tokyo/    → terraform apply     # Creates VPC, TGW, RDS, peering request
3. cd saopaulo/ → terraform apply     # Accepts peering, adds TGW routes
4. Verify cross-region connectivity    # SP EC2 → Tokyo RDS via TGW
```

### Why Hardcoded IDs?

The TGW configuration files contain hardcoded resource IDs (peering attachment IDs, route table IDs). This is intentional — these values are **cross-state references** between two independent Terraform roots. In production, you'd use `terraform_remote_state` data sources or SSM Parameter Store lookups. For this lab, the IDs are hardcoded with comments explaining their origin.

## Repository Structure

```
armageddon_2026/
├── README.md
├── .gitignore
├── tokyo/                          # Data authority region
│   ├── main.tf                     # VPC, subnets, RDS, IAM, EC2, SSM params, secrets
│   ├── bonus_b.tf                  # ALB, TLS, WAF, CloudWatch dashboard, alarms
│   ├── bonus_b_route53.tf          # Route53 hosted zone, DNS management
│   ├── bonus_b_variables.tf        # Domain, WAF, alarm threshold variables
│   ├── tokyo_tgw.tf                # Transit Gateway hub + peering request
│   ├── tokyo_routes.tf             # TGW routes to São Paulo
│   ├── rds_sg_sp.tf                # RDS SG rule: allow São Paulo CIDR
│   ├── variables.tf                # Core infrastructure variables
│   ├── outputs.tf                  # VPC, EC2, RDS, TGW outputs
│   ├── providers.tf                # AWS provider (ap-northeast-1)
│   ├── versions.tf                 # Terraform + provider version constraints
│   ├── user_data.sh                # EC2 bootstrap: Flask app + systemd service
│   └── terraform.tfvars.example    # Example variable values (no secrets)
├── saopaulo/                       # Stateless compute region
│   ├── main.tf                     # VPC, subnets, IAM, EC2 (private), CloudWatch
│   ├── bonus_a.tf                  # VPC Endpoints (7), least-privilege IAM
│   ├── bonus_a_outputs.tf          # VPC Endpoint ID outputs
│   ├── bonus_b.tf                  # ALB, TLS, WAF, CloudWatch dashboard, alarms
│   ├── bonus_b_route53.tf          # Route53 hosted zone, DNS management
│   ├── bonus_b_variables.tf        # Domain, WAF, alarm threshold variables
│   ├── sp_tgw.tf                   # Transit Gateway spoke + accept peering
│   ├── sp_tg_routes.tf             # TGW routes to Tokyo
│   ├── variables.tf                # Core infrastructure variables
│   ├── outputs.tf                  # VPC, EC2, ALB, TGW outputs
│   ├── providers.tf                # AWS provider (sa-east-1)
│   ├── versions.tf                 # Terraform + provider version constraints
│   ├── user_data.sh                # EC2 bootstrap: Flask app + systemd service
│   └── terraform.tfvars.example    # Example variable values (no secrets)
├── scripts/                        # Verification and audit tooling
│   ├── gate_secrets_and_role.sh    # Validates IAM + Secrets Manager config
│   ├── gate_network_db.sh          # Validates network + RDS security
│   ├── run_all_gates.sh            # Runs all gate scripts
│   ├── malgus_residency_proof.py   # Data residency compliance evidence
│   ├── malgus_tgw_corridor_proof.py# TGW connectivity evidence
│   ├── malgus_waf_summary.py       # WAF configuration evidence
│   └── ...                         # Additional audit/verification scripts
└── evidence/                       # Audit pack and verification outputs
    ├── lab1c_core_evidence.txt
    ├── bonus_a_evidence.txt
    ├── bonus_b_evidence.txt
    ├── bonus_c_evidence.txt
    └── lab3b_audit_pack/
```

## Key Design Decisions

**Why Transit Gateway instead of VPC Peering?**
TGW supports transitive routing, scales to multiple regions, and provides centralized route management. VPC peering would work for two regions but doesn't scale.

**Why VPC Endpoints in São Paulo?**
EC2 is in a private subnet with no public IP. VPC Endpoints allow it to reach AWS APIs (SSM, CloudWatch, S3, Secrets Manager, KMS) without routing through NAT — reducing cost, latency, and attack surface.

**Why separate Terraform roots per region?**
Industry standard for multi-region. Each region can be deployed, updated, or destroyed independently. Blast radius is contained — a bad `terraform apply` in São Paulo can't affect Tokyo's RDS.

**Why hardcoded credentials in user_data.sh?**
They're not hardcoded — the Flask app reads credentials from Secrets Manager at runtime via `boto3`. The `user_data.sh` script only sets the secret _name_ (`shinjuku/rds/mysql`) as an environment variable, not the actual password.

## Labs Completed

| Lab | Description | Status |
|---|---|---|
| 1A | EC2 → RDS, Security Groups, IAM, Secrets Manager | ✅ |
| 1B | Parameter Store, CloudWatch, Alarms, SNS, Incident Response | ✅ |
| 1C | Full Terraform IaC for all Lab 1A/1B resources | ✅ |
| 1C Bonus A | VPC Endpoints, Private EC2, SSM Session Manager, Least-Privilege IAM | ✅ |
| 1C Bonus B | ALB, TLS/ACM, WAF, CloudWatch Dashboard, 5xx Alarm | ✅ |
| 1C Bonus C | Route53, ACM DNS Validation | ✅ |
| 2 | CloudFront Origin Cloaking, Cache Correctness | ✅ |
| 3A | Transit Gateway Cross-Region Peering (Tokyo ↔ São Paulo) | ✅ |
| 3B | APPI Compliance Audit Evidence Pack | ✅ |

## Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/armageddon_2026.git
cd armageddon_2026

# 2. Configure variables
cp tokyo/terraform.tfvars.example tokyo/terraform.tfvars
cp saopaulo/terraform.tfvars.example saopaulo/terraform.tfvars
# Edit both files with your values

# 3. Deploy São Paulo first (creates TGW for Tokyo to peer with)
cd saopaulo/
terraform init && terraform apply

# 4. Deploy Tokyo (creates RDS, peering request)
cd ../tokyo/
terraform init && terraform apply

# 5. Return to São Paulo to accept peering + add routes
cd ../saopaulo/
terraform apply

# 6. Verify cross-region connectivity
aws ssm start-session --target <SP_INSTANCE_ID> --region sa-east-1
# From inside the session:
aws secretsmanager get-secret-value --secret-id shinjuku/rds/mysql --region ap-northeast-1 --query "Name"
```

## Author

Larry Shelton — Cloud Infrastructure Engineer
