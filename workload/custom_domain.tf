###############################################################################
# custom_domain.tf — Workload
# ----------------------------------------------------------------------------
# Creates two custom domains on Front Door:
#   1. www.mokcloud.site   — subdomain (CNAME-based)
#   2. mokcloud.site       — apex/root domain (A alias-based)
#
# Each custom domain gets a FREE, auto-renewing managed TLS certificate
# from Microsoft (via DigiCert). Certificate provisioning can take up to
# 15 minutes after domain validation completes.
#
# The dns_zone_id tells Front Door "this domain is managed in Azure DNS"
# which enables automatic TXT record creation for domain validation.
#
# IMPORTANT: After terraform apply, the custom domain association resource
# explicitly links each domain to the route. Without this, Front Door has
# the domain registered but doesn't know which route should serve it.
#
# Reference:
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_custom_domain
#   https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-add-custom-domain
#   https://learn.microsoft.com/en-us/azure/frontdoor/apex-domain
###############################################################################

# ─── www Custom Domain ──────────────────────────────────────────────────────
# The "www" subdomain — www.mokcloud.site
# Uses a CNAME record (created in dns_records.tf) pointing to the Front Door
# endpoint hostname.
resource "azurerm_cdn_frontdoor_custom_domain" "www" {
  name                     = "custom-domain-www"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  dns_zone_id              = var.dns_zone_id
  host_name                = "www.${var.dns_zone_name}"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

# ─── Apex Custom Domain ────────────────────────────────────────────────────
# The apex/root domain — mokcloud.site (no www prefix)
# Uses an A alias record (created in dns_records.tf) pointing to the Front
# Door endpoint. Regular A records need a fixed IP, but Front Door's IPs
# change. Alias records solve this by pointing to the Azure resource directly.
resource "azurerm_cdn_frontdoor_custom_domain" "apex" {
  name                     = "custom-domain-apex"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  dns_zone_id              = var.dns_zone_id
  host_name                = var.dns_zone_name

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

# ─── Domain Associations ────────────────────────────────────────────────────
# These resources explicitly link each custom domain to the route.
# Without them, the domain is registered in Front Door but traffic
# isn't routed — the site would return errors on the custom domain.
#
# Think of it as: the custom domain is the "name tag", the route is the
# "path to the kitchen", and the association staples them together.
resource "azurerm_cdn_frontdoor_custom_domain_association" "www" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.www.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.default.id]
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "apex" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.apex.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.default.id]
}
