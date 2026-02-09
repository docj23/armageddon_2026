############################################
# Bonus C — Route53 Hosted Zone + DNS Management
# Manages the domain's hosted zone and provides
# the zone ID for ACM DNS validation and app ALIAS records.
############################################

locals {
  chewbacca_zone_name = var.domain_name

  # Use Terraform-managed zone or a pre-existing zone ID.
  chewbacca_zone_id = var.manage_route53_in_terraform ? aws_route53_zone.chewbacca_zone01[0].zone_id : var.route53_hosted_zone_id

  chewbacca_app_fqdn = "${var.app_subdomain}.${var.domain_name}"
}

############################################
# Hosted Zone (optional creation)
############################################

# Route53 hosted zone for the custom domain.
# Set manage_route53_in_terraform = true to create, or false to
# use an existing zone (provide route53_hosted_zone_id).
resource "aws_route53_zone" "chewbacca_zone01" {
  count = var.manage_route53_in_terraform ? 1 : 0

  name = local.chewbacca_zone_name

  tags = {
    Name = "${var.project_name}-zone01"
  }
}

# NOTE: ACM DNS validation records were created manually in Route53
# during initial deployment. For a fully automated pipeline, uncomment
# and configure aws_route53_record resources for ACM validation CNAMEs
# and an ALIAS record pointing the app subdomain to the ALB.
