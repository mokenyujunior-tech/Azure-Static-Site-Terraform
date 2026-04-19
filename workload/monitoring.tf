###############################################################################
# monitoring.tf — Workload
# ----------------------------------------------------------------------------
# Creates the monitoring stack:
#   1. Log Analytics workspace — the "notebook" where logs are stored
#   2. Diagnostic setting      — the "pipe" sending Front Door logs to it
#   3. Budget alert            — email notification if costs exceed threshold
#
# WHAT GETS LOGGED:
#   - FrontDoorAccessLog:     Every visitor request (URL, status code, latency,
#                             cache hit/miss, client IP, user agent)
#   - FrontDoorHealthProbeLog: Every health check Front Door makes to your
#                              storage origins (healthy/unhealthy status)
#   - AllMetrics:             Numeric data (request count, bandwidth, latency)
#
# WHY LOG ANALYTICS (NOT JUST AZURE MONITOR)?
#   Azure Monitor shows real-time metrics but doesn't retain detailed logs
#   for querying. Log Analytics lets you write KQL queries like "show me
#   all 404 errors from the last 7 days" or "what's my cache hit ratio?"
#   That's the proof your CDN is working — essential for the README.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview
#   https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/diagnostic-settings
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting
###############################################################################

# ─── Log Analytics Workspace ────────────────────────────────────────────────
# The central data store for all logs. Retains data for 30 days by default
# (free tier). You can increase retention but it costs more.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_short_name}-prod"
  resource_group_name = azurerm_resource_group.workload.name
  location            = var.primary_location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.common_tags, {
    costcategory = "Monitoring"
  })
}

# ─── Diagnostic Setting: Front Door → Log Analytics ─────────────────────────
# This pipes Front Door's logs and metrics into the Log Analytics workspace.
# Without this, Front Door generates data but sends it nowhere — you're blind.
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = "diag-afd-to-law"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # ── Access logs: every visitor request ──
  enabled_log {
    category = "FrontDoorAccessLog"
  }

  # ── Health probe logs: origin health checks ──
  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }

  # ── All numeric metrics ──
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ─── Budget Alert ───────────────────────────────────────────────────────────
# Sends an email when the resource group spend crosses 80% or 100% of the
# budget. The $50 threshold gives ~40% headroom above the expected ~$36/month.
#
# The budget is scoped to the workload resource group only — it doesn't
# track rg-dns-shared costs (which are just $0.50/month for the DNS zone).
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${var.project_short_name}-monthly"
  resource_group_id = azurerm_resource_group.workload.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  # Alert at 80% actual spend
  notification {
    operator       = "GreaterThanOrEqualTo"
    threshold      = 80
    contact_emails = [var.alert_email]
    enabled        = true
    threshold_type = "Actual"
  }

  # Alert at 100% actual spend
  notification {
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    contact_emails = [var.alert_email]
    enabled        = true
    threshold_type = "Actual"
  }

  # Alert at 100% forecasted spend
  notification {
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    contact_emails = [var.alert_email]
    enabled        = true
    threshold_type = "Forecasted"
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
