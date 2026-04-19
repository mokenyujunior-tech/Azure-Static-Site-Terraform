###############################################################################
# variables.tf — Bootstrap
# ----------------------------------------------------------------------------
# Inputs for the one-time DNS zone deployment. These values rarely change.
#
# Why so few variables?
#   The bootstrap folder only creates two resources: a resource group and a
#   DNS zone. Everything else lives in the workload folder.
###############################################################################

variable "subscription_id" {
  description = "Azure subscription ID. Find it in the portal under Subscriptions."
  type        = string
}

variable "location" {
  description = "Azure region for the DNS resource group. The DNS zone itself is global, but the RG metadata needs a region."
  type        = string
  default     = "canadacentral"
}

variable "dns_resource_group_name" {
  description = "Name of the permanent resource group that holds the DNS zone. This RG is never deleted."
  type        = string
  default     = "rg-dns-shared"
}

variable "domain_name" {
  description = "Your custom domain name exactly as registered with your registrar (e.g., mokcloud.site). No www, no https://."
  type        = string
  default     = "mokcloud.site"
}

variable "tags" {
  description = "Tags applied to the DNS resource group and zone."
  type        = map(string)
  default = {
    project     = "az-static-site"
    environment = "prod"
    owner       = "mk"
    department  = "IT"
  }
}
