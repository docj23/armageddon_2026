# Armageddon Project — Full Analysis (Claude Code Conversation Summary)

**Date:** March 19, 2026
**Context:** Analysis of Larry's completed multi-region cloud infrastructure project vs. the original assignment from professor.

---

## Repos Analyzed

- **Original assignment:** https://github.com/docj23/armageddon
- **My completed work:** https://github.com/docj23/armageddon_2026

---

## What The Assignment Is

A **regulation-aware, multi-region cloud engineering lab series** (not a tutorial). Core scenario: a Japanese medical organization that must comply with **APPI** (Japan's privacy law) — patient data (PHI) can never leave Japan, but the system must be globally accessible.

**Philosophy:** "Global access does not require global storage." The project teaches **judgment**, not commands.

---

## 5 Labs in the SEIR_Foundations Track

| Lab | Topic | My Status |
|-----|-------|-----------|
| **Lab 1** | EC2 → RDS foundation + Terraform IaC + 9 Bonus Tracks (A-I) | **Partially Complete** (see details below) |
| **Lab 2** | CloudFront origin cloaking + cache policies | **Complete** |
| **Lab 3** | Cross-region Transit Gateway + APPI compliance | **Complete** |
| **Lab 4** | Multi-cloud AWS + GCP (IPSec VPN + BGP) | **Planned** |
| **Lab 5** | Red vs Blue security (OWASP attack/defend) + Llama AI | **Planned** |

---

## What I Built (Labs 1-3)

### Architecture

```
Tokyo (ap-northeast-1) — Data Authority
├── RDS MySQL (private, no replicas)
├── EC2 Flask App
├── Secrets Manager + Parameter Store
├── ALB + WAF + ACM (TLS 1.3)
├── CloudWatch Logs/Alarms/Dashboard + SNS
└── Transit Gateway (Hub)
        |
    TGW Peering Corridor
        |
São Paulo (sa-east-1) — Stateless Compute
├── EC2 Flask App (private, no public IP)
├── 7 VPC Endpoints (zero-trust networking)
├── ALB + WAF + ACM
├── SSM Session Manager (no SSH keys)
└── Transit Gateway (Spoke)
```

### By the Numbers

- ~27 Terraform files, ~1,900+ lines of IaC
- 2 independent Terraform roots (tokyo/, saopaulo/)
- 109+ AWS resources deployed
- 48 proof screenshots
- 11 audit pack documents
- Flask app with 4 endpoints, cross-region DB access via Secrets Manager

---

## Quality Assessment

### What I Did Well

1. **Security** — SG-to-SG references (not CIDR blocks), RDS in private subnet only, Secrets Manager for credentials (no hardcoding), VPC Endpoints to eliminate NAT exposure, least-privilege IAM in São Paulo, WAF on ALB, TLS 1.3
2. **Compliance** — RDS exists ONLY in Tokyo (verified), São Paulo is stateless compute only, TGW provides auditable data corridor, audit pack proves data residency
3. **Observability** — CloudWatch Logs, DB connection error alarms, ALB 5xx alarms, SNS alerting, CloudWatch Dashboard
4. **IaC Discipline** — Clean modular Terraform, no secrets committed, `.tfvars.example` provided, comprehensive comments
5. **Bonus Work** — Completed ALL three Lab 1C bonuses A, B, C (beyond base requirement)
6. **Audit Pack** — 11 evidence documents with CLI proof, professional-grade compliance documentation

### Minor Observations (Not Blockers)

1. **Tokyo IAM is broader than São Paulo** — São Paulo has custom least-privilege policies (Bonus A), but Tokyo still uses `SecretsManagerReadWrite` managed policy. Could tighten for consistency.
2. **Cross-state references are hardcoded** — TGW attachment IDs between regions are hardcoded with comments. Production would use `terraform_remote_state` or SSM. Fine for a lab.
3. **São Paulo DNS** — ALB accessed via ALB DNS name rather than a domain ALIAS record. Functional but not optimized.

---

## Lab 1 — The Complete Map

Lab 1 has 3 sub-labs (1A, 1B, 1C) plus **9 bonus tracks** on 1C:

### Base Labs

| Sub-Lab | Topic | Status |
|---------|-------|--------|
| **1A** | EC2 → RDS + IAM + Secrets Manager (manual deploy) | **Done** |
| **1B** | CloudWatch + Alarms + SNS + Incident Response | **Done** |
| **1C** | Full Terraform IaC (rewrite 1A+1B as code) | **Done** |

### Bonus Tracks (1C)

| Bonus | Topic | Status |
|-------|-------|--------|
| **A** | Private EC2 + VPC Endpoints + SSM + Least-Privilege IAM | **Done** |
| **B** | ALB + TLS/HTTPS + WAF + Dashboard | **Done** |
| **C** | Route53 + ACM DNS Validation | **Done** |
| **D** | ALB Access Logs → S3 + Apex DNS | **Not yet** |
| **E** | WAF Logging (CloudWatch / S3 / Firehose — pick one) | **Not yet** |
| **F** | CloudWatch Logs Insights Query Pack (8 query templates) | **Not yet** |
| **G** | **Amazon Bedrock Auto-Incident-Report Pipeline (AI)** | **Not yet** |
| **H** | **Bedrock IR Student Handout (integration contract)** | **Not yet** |
| **I** | **Bedrock + Human Hybrid Runbook** | **Not yet** |

---

## The AI Layer — Bonuses G, H, I (Amazon Bedrock)

This is the AI integration my professor mentioned.

### Architecture

```
CloudWatch Alarm fires
    ↓
SNS notification
    ↓
Lambda function triggers
    ↓
Lambda queries CloudWatch Logs Insights (app errors + WAF logs)
Lambda pulls config from SSM Parameter Store + Secrets Manager
    ↓
Lambda calls Amazon Bedrock (Claude) with evidence + anti-hallucination rules
    ↓
Bedrock generates structured incident report (Markdown)
    ↓
Lambda stores report + evidence bundle to S3
Lambda notifies via SNS
    ↓
Human on-call engineer reviews, verifies, and owns the final decision
```

### Core Philosophy

**"Bedrock accelerates analysis. Humans own correctness."**

### Anti-Hallucination Rules Baked Into Prompt

- Use ONLY evidence
- If unknown, say "Unknown"
- Include confidence levels
- Cite the evidence key used for each claim
- Never fabricate CVEs or resources
- Recommend next evidence to pull

### Code Provided (Framework — I Adapt)

- `handler.py` — Full Lambda implementation calling `bedrock.invoke_model()`
- `claude.py` — Reference implementation for Anthropic Claude via Bedrock
- `bonus_G_bedrock_autoreport.tf` — Terraform for Lambda, IAM, S3, SNS wiring

### Logical Progression

D → E → F → G → H → I

The logging (D, E) feeds the queries (F), the queries feed Bedrock (G), Bedrock feeds the human (H, I).

---

## Lab 5 Also Has AI — Local Llama

Lab 5A-Plus uses a **local Llama model** (via Ollama) to consolidate Red Team security tool outputs (ZAP, Trivy, Checkov, tfsec, Prowler, Grype) into one analyst-ready report. A working Python implementation (`5a_merge_reports.py`) is provided.

---

## What's Ahead (My Remaining Plan)

### Lab 1 Remaining (Bonuses D-I)
- **D-E-F**: Build the logging/observability foundation
- **G-H-I**: Deploy the Bedrock AI incident response pipeline

### Lab 4: Multi-Cloud (AWS + GCP)
- IPSec VPN tunnels between AWS Tokyo and GCP Iowa
- BGP for dynamic route exchange
- GCP Managed Instance Group + Internal HTTPS LB
- PSK discipline (secure key management)
- Still no data outside Tokyo

### Lab 5: Red vs Blue Security
- Red Team: 8+ findings mapped to OWASP Top 10 (nmap, ZAP, trivy, checkov, prowler)
- Blue Team: Remediate, verify, document
- Lab 5A-Plus: Local Llama report consolidation
- Full "red packet" deliverable with evidence artifacts

---

## Career Context (From Professor's README)

Completing Labs 1-3 + AWS SAA + Terraform Associate:
- **Roles:** Cloud Engineer, Junior DevOps, Infrastructure Engineer, Platform Engineer (Junior), SRE (Entry)
- **Salary (US):** $90k–$140k
- **Market position:** 75th–85th percentile in cloud

---

## CKA / CKAD Side Discussion

During this same conversation, Claude confirmed that my **Kubernetes Mastery course** (10 phases, 141 files) covers:
- **100% of CKA exam domains** (all 5 domains fully covered)
- **~95% of CKAD exam domains** (deployment strategies covered in ArgoCD/Flux courses)

Study plan pacing options:
- Intensive: 8-10 weeks at 20-25 hrs/week
- Standard: 16-20 weeks at 12-15 hrs/week
- Relaxed: 24-30 weeks at 6-8 hrs/week

---

*This summary was generated from a Claude Code (CLI) conversation on March 19, 2026.*
