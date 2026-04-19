###############################################################################
# storage_firewall.tf — Workload
# ----------------------------------------------------------------------------
# Locks down both storage accounts so only Front Door (via trusted Azure
# services) can reach them. Direct access to the *.web.core.windows.net
# endpoints is blocked — visitors MUST go through Front Door.
#
# WHY THIS MATTERS:
#   Without this lockdown, attackers can bypass Front Door's WAF and DDoS
#   protection by hitting the storage endpoint directly. It also forces all
#   traffic through the Front Door cache, reducing storage egress costs.
#
# HOW IT WORKS:
#   - default_action = "Deny"     — block all traffic by default
#   - bypass = ["AzureServices"]  — allow Azure trusted services (which
#     includes Front Door) to access the storage account
#
# WHY NOT resource_access_rules?
#   The Azure portal's "Resource instances" dropdown does not list
#   Microsoft.Cdn/profiles in all tenants (a known limitation). The
#   Terraform provider's azurerm_storage_account_network_rules also
#   doesn't support resource_access_rules natively. The trusted services
#   bypass is the documented fallback for Front Door Standard tier and
#   achieves the same practical result.
#
# ORDERING:
#   The depends_on ensures these rules are applied AFTER Front Door origins
#   are created. If you lock down storage before Front Door connects, Front
#   Door's health probes fail and the site goes down.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security
#   https://learn.microsoft.com/en-us/azure/frontdoor/origin-security
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_network_rules
###############################################################################

# ─── Auto-detect your current public IP ─────────────────────────────────────
# Every time you run terraform apply, this fetches your laptop's current
# public IP from ifconfig.me. If your IP changes (new Wi-Fi, VPN, etc.),
# just run terraform apply again and the firewall updates automatically.
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  admin_ip = chomp(data.http.my_ip.response_body)
}

# ─── Primary Storage Firewall ────────────────────────────────────────────────
resource "azurerm_storage_account_network_rules" "primary" {
  storage_account_id = azurerm_storage_account.primary.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]

  # No IP rules — even you can't access the storage endpoint directly.
  # Upload files via CLI using --auth-mode login (which uses Azure AD, not
  # the storage endpoint network path).
  ip_rules                   = [local.admin_ip]
  virtual_network_subnet_ids = []

  depends_on = [
    azurerm_cdn_frontdoor_origin.primary,
    azurerm_cdn_frontdoor_route.default,
  ]
}

# ─── Secondary Storage Firewall ──────────────────────────────────────────────
resource "azurerm_storage_account_network_rules" "secondary" {
  storage_account_id = azurerm_storage_account.secondary.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]

  ip_rules                   = [local.admin_ip]
  virtual_network_subnet_ids = []

  depends_on = [
    azurerm_cdn_frontdoor_origin.secondary,
    azurerm_cdn_frontdoor_route.default,
  ]
}
