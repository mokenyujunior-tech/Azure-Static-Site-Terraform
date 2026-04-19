###############################################################################
# outputs.tf — Bootstrap
# ----------------------------------------------------------------------------
# After terraform apply, these values are printed to your terminal.
# The nameservers are the most important — you paste them into Namecheap.
#
# The dns_zone_id is used by the workload folder to reference this zone
# without managing it. You'll copy this value into the workload tfvars.
###############################################################################

output "nameservers" {
  description = "The 4 Azure DNS nameservers. Paste these into Namecheap → Domain List → mokcloud.site → Custom DNS (without the trailing dots)."
  value       = azurerm_dns_zone.main.name_servers
}

output "dns_zone_id" {
  description = "The full resource ID of the DNS zone. Copy this into the workload terraform.tfvars as dns_zone_id."
  value       = azurerm_dns_zone.main.id
}

output "dns_zone_name" {
  description = "The DNS zone name (your domain)."
  value       = azurerm_dns_zone.main.name
}

output "dns_resource_group_name" {
  description = "The resource group name where the DNS zone lives."
  value       = azurerm_resource_group.dns.name
}
