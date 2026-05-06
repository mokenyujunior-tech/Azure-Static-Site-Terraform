###############################################################################
# frontdoor.tf — Workload
# ----------------------------------------------------------------------------
# Creates the Azure Front Door Standard profile with:
#   - 1 endpoint          (the public *.azurefd.net URL)
#   - 1 origin group      (container for both storage origins)
#   - 2 origins           (primary in Canada Central, secondary in East US)
#   - 1 route             (wires domains to the origin group with caching)
#
# ARCHITECTURE:
#   Visitor → Front Door POP (nearest edge) → health-checks both origins →
#   routes to the nearest healthy origin → serves cached content or fetches
#   from storage → caches response for future visitors.
#
# HEALTH PROBE SET TO HTTPS:
#   Lesson learned from the portal build — storage accounts with "Require
#   secure transfer" enabled reject HTTP health probes. Protocol must be
#   Https or the origin shows as unhealthy and Front Door returns errors.
#
# CACHING:
#   - query_string_caching_behavior = "IgnoreQueryString" — static sites
#     don't vary by query string, so ignoring them maximizes cache hits.
#   - compression_enabled = true — Front Door auto-compresses HTML, CSS, JS
#     with gzip/brotli, reducing bandwidth and improving load times.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/frontdoor/create-front-door-terraform
#   https://learn.microsoft.com/en-us/azure/frontdoor/origin
#   https://learn.microsoft.com/en-us/azure/frontdoor/scenario-storage-blobs
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_profile
###############################################################################

# ─── Front Door Profile ─────────────────────────────────────────────────────
# The top-level container for all Front Door resources. Standard tier
# includes caching, compression, custom WAF rules, DDoS protection, and
# managed certificates. Premium adds managed WAF rules, bot protection,
# and Private Link (~$330/month). Standard is correct for a static site.
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                     = "afd-${var.project_short_name}-prod"
  resource_group_name      = azurerm_resource_group.workload.name
  sku_name                 = "Standard_AzureFrontDoor"
  response_timeout_seconds = 60

  tags = merge(var.common_tags, {
    costcategory = "Networking"
  })
}

# ─── Front Door Endpoint ────────────────────────────────────────────────────
# The public entry point. Azure assigns a globally unique hostname like
# ep-mksite-prod-<hash>.z01.azurefd.net. This endpoint already has a
# Microsoft-issued TLS certificate built in.
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "ep-${var.project_short_name}-prod"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  enabled                  = true

  tags = merge(var.common_tags, {
    costcategory = "Networking"
  })
}

# ─── Origin Group ───────────────────────────────────────────────────────────
# A container for both storage account origins. Front Door health-probes
# both origins and load-balances between them using latency-based routing.
#
# If the primary origin in Canada Central goes down, Front Door automatically
# routes all traffic to the secondary origin in East US. Zero downtime,
# zero manual intervention.
#
# health_probe:
#   - protocol = "Https" — CRITICAL: must match storage account's secure
#     transfer requirement. HTTP probes get rejected → origin marked unhealthy.
#   - path = "/" — probes the root URL which returns index.html.
#   - interval = 100 seconds — low frequency to minimize probe costs.
#   - request_type = "HEAD" — cheaper than GET; only checks if the page exists.
#
# load_balancing:
#   - sample_size = 4 — number of recent probes to consider.
#   - successful_samples_required = 3 — origin is healthy if 3 of 4 pass.
#   - additional_latency_in_milliseconds = 50 — origins within 50ms of each
#     other are considered equally close. This prevents flip-flopping between
#     origins that have similar latency.
resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                     = "og-${var.project_short_name}-web"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

# ─── Primary Origin (Canada Central) ────────────────────────────────────────
# Points to the primary storage account's static website endpoint.
#
# IMPORTANT: host_name uses primary_web_host (the *.z##.web.core.windows.net
# endpoint), NOT the blob endpoint (*.blob.core.windows.net). The blob
# endpoint doesn't serve index.html automatically — it's the #1 mistake.
#
# priority = 1: This origin is preferred. Front Door sends traffic here
# unless it's unhealthy.
# weight = 1000: When both origins are healthy and have similar latency,
# traffic is distributed by weight. Equal weights = equal distribution.
resource "azurerm_cdn_frontdoor_origin" "primary" {
  name                           = "origin-${var.project_short_name}-pri"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                        = true
  certificate_name_check_enabled = true

  host_name          = azurerm_storage_account.primary.primary_web_host
  origin_host_header = azurerm_storage_account.primary.primary_web_host
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000

  depends_on = [azurerm_storage_blob.primary]
}

# ─── Secondary Origin (East US) ─────────────────────────────────────────────
# Same configuration as primary but pointing to the secondary storage account.
# priority = 2: Front Door only routes here if the primary origin is unhealthy.
#
# In a real company with equal traffic across regions, you might set both
# priorities to 1 and let latency-based routing decide. For this project,
# we use active-passive (primary=1, secondary=2) to keep costs predictable.
resource "azurerm_cdn_frontdoor_origin" "secondary" {
  name                           = "origin-${var.project_short_name}-sec"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                        = true
  certificate_name_check_enabled = true

  host_name          = azurerm_storage_account.secondary.primary_web_host
  origin_host_header = azurerm_storage_account.secondary.primary_web_host
  http_port          = 80
  https_port         = 443
  priority           = 2
  weight             = 1000

  depends_on = [azurerm_storage_blob.secondary]
}

# ─── Route ──────────────────────────────────────────────────────────────────
# The "wiring" that connects domains to the origin group. Without a route,
# Front Door has an endpoint and origins but no instructions connecting them.
#
# This route says:
#   - Accept traffic on the default endpoint domain AND both custom domains
#   - Match all URL paths (/*) 
#   - Forward using HTTPS only (HttpsOnly)
#   - Redirect HTTP to HTTPS automatically
#   - Cache with query string ignored and compression enabled
resource "azurerm_cdn_frontdoor_route" "default" {
  name                          = "route-default"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id

  cdn_frontdoor_origin_ids = [
    azurerm_cdn_frontdoor_origin.primary.id,
    azurerm_cdn_frontdoor_origin.secondary.id,
  ]

  enabled                = true
  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  # Link custom domains to this route (Front Door serves certs for these)
  cdn_frontdoor_custom_domain_ids = [
    azurerm_cdn_frontdoor_custom_domain.www.id,
    azurerm_cdn_frontdoor_custom_domain.apex.id,
  ]

  # Also serve traffic on the default *.azurefd.net domain
  link_to_default_domain = true

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress     = [
      "text/html",
      "text/css",
      "text/javascript",
      "application/javascript",
      "application/json",
      "application/xml",
      "image/svg+xml",
    ]
  }

  depends_on = [
    azurerm_cdn_frontdoor_origin_group.web,
    azurerm_cdn_frontdoor_origin.primary,
    azurerm_cdn_frontdoor_origin.secondary,
  ]
}
