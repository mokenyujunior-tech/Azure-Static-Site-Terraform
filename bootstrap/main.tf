###############################################################################
# main.tf — Bootstrap
# ----------------------------------------------------------------------------
# Creates TWO resources that live permanently and are NEVER destroyed:
#
#   1. rg-dns-shared        — Resource group to hold the DNS zone.
#   2. mokcloud.site (zone)  — Azure DNS zone for our custom domain.
#
# WHY SEPARATE?
#   When you delete an Azure DNS zone and recreate it, Azure assigns NEW
#   nameservers. Your registrar (Namecheap) would still point at the old
#   ones, breaking DNS until you manually update them. By keeping the DNS
#   zone in its own resource group, you can freely destroy and rebuild the
#   workload (storage, Front Door, monitoring) without ever touching
#   Namecheap again.
#
# LIFECYCLE:
#   - Run this ONCE: terraform init → terraform apply
#   - Copy the 4 nameservers from the output
#   - Paste them into Namecheap → Domain List → mokcloud.site → Custom DNS
#   - Never run terraform destroy on this folder unless you're abandoning
#     the domain entirely
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_zone
###############################################################################

# ─── Resource Group ──────────────────────────────────────────────────────────
# A container for the DNS zone. Tagged but never deleted.
resource "azurerm_resource_group" "dns" {
  name     = var.dns_resource_group_name
  location = var.location
  tags     = var.tags
}

# ─── DNS Zone ────────────────────────────────────────────────────────────────
# This is the "phone book" for mokcloud.site. Azure assigns 4 nameservers
# when the zone is created. Those nameservers are what you paste into
# Namecheap to delegate DNS authority to Azure.
#
# The zone itself is a global resource — it doesn't live in one region.
# The location on the resource group is just metadata storage.
resource "azurerm_dns_zone" "main" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}
