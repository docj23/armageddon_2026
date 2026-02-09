# Bonus B Variables

variable "domain_name" {
  description = "Your domain name"
  type        = string
  default     = "cigarsrmypassion.click"
}

variable "app_subdomain" {
  description = "Subdomain for app (use empty string for apex)"
  type        = string
  default     = ""
}

variable "manage_route53_in_terraform" {
  description = "Manage Route53 hosted zone in Terraform"
  type        = bool
  default     = false  # CHANGED FROM true TO false
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID if not managing in Terraform"
  type        = string
  default     = "Z02253234ZXKFENT1HKK"  # YOUR ORIGINAL ZONE
}

variable "create_acm_certificate" {
  description = "Create ACM certificate for HTTPS"
  type        = bool
  default     = true
}

variable "certificate_validation_method" {
  description = "ACM certificate validation method"
  type        = string
  default     = "DNS"
}

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "alb_5xx_evaluation_periods" {
  description = "Number of periods for ALB 5xx alarm"
  type        = number
  default     = 2
}

variable "alb_5xx_threshold" {
  description = "Threshold for ALB 5xx alarm"
  type        = number
  default     = 10
}

variable "alb_5xx_period_seconds" {
  description = "Period in seconds for ALB 5xx alarm"
  type        = number
  default     = 300
}
