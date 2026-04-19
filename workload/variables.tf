###############################################################################
# variables.tf — Workload
# ----------------------------------------------------------------------------
# All configurable inputs for the static site infrastructure.
#
# REQUIRED variables (no defaults):
#   - subscription_id
#   - dns_zone_id
#
# OPTIONAL variables (sensible defaults provided):
#   - Everything else. Defaults match your mokcloud.site project.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
###############################################################################

# ─── Identity ────────────────────────────────────────────────────────────────

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID. Used for storage firewall resource access rules."
  type        = string
  default     = "6d1a1189-71c0-454f-bd1d-208980e7c2d5"
}

variable "admin_ip" {
  description = "Your public IP address. Allows CLI uploads and portal access to storage while firewall is set to Deny. Find it at https://ifconfig.me"
  type        = string
  default     = "205.189.187.4"
}

# ─── DNS (from bootstrap) ────────────────────────────────────────────────────

variable "dns_zone_id" {
  description = "Full resource ID of the DNS zone created by the bootstrap folder. Get this from: cd ../bootstrap && terraform output dns_zone_id"
  type        = string
}

variable "dns_zone_name" {
  description = "The domain name (e.g., mokcloud.site). Must match the bootstrap DNS zone name."
  type        = string
  default     = "mokcloud.site"
}

variable "dns_resource_group_name" {
  description = "Resource group name where the DNS zone lives. Must match the bootstrap RG."
  type        = string
  default     = "rg-dns-shared"
}

# ─── Regions ─────────────────────────────────────────────────────────────────

variable "primary_location" {
  description = "Primary Azure region. Closest to your users in Toronto."
  type        = string
  default     = "canadacentral"
}

variable "secondary_location" {
  description = "Secondary Azure region for multi-region redundancy. Front Door routes to the nearest healthy origin."
  type        = string
  default     = "eastus"
}

# ─── Naming ──────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the workload resource group. This RG can be destroyed and rebuilt freely."
  type        = string
  default     = "rg-staticsite-prod"
}

variable "project_short_name" {
  description = "Short name used in resource names to avoid collisions (e.g., storage account names must be globally unique)."
  type        = string
  default     = "mksite"
}

# ─── Budget ──────────────────────────────────────────────────────────────────

variable "budget_amount" {
  description = "Monthly budget in USD. Alert triggers at 80% and 100%."
  type        = number
  default     = 50
}

variable "alert_email" {
  description = "Email address that receives budget alerts and cost notifications."
  type        = string
  default     = "mokenyukezongwe@outlook.com"
}

# ─── Tags ────────────────────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to every resource. costcategory is set per-resource, not here."
  type        = map(string)
  default = {
    project     = "az-static-site"
    environment = "prod"
    owner       = "mk"
    department  = "IT"
    managed-by  = "terraform"
  }
}
