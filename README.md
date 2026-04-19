# Azure Static Website Hosting — Terraform

A globally distributed, HTTPS-secured static website on Azure for a small company, deployed entirely with Terraform.

**Live URL:** `https://mokcloud.site` | `https://www.mokcloud.site`

## Architecture

```
                     ┌──────────────────────────────────┐
  Visitor (browser)  │  mokcloud.site / www.mokcloud.site│
        │            └──────────────┬───────────────────┘
        │                           │ DNS lookup
        ▼                           ▼
   ┌─────────┐               ┌────────────┐
   │ Azure   │  CNAME/Alias  │ Azure DNS  │
   │ Front   │◄──────────────│ Zone       │
   │ Door    │               │ (rg-dns-   │
   │ Std     │               │  shared)   │
   └────┬────┘               └────────────┘
        │ Latency-based routing
        ├──────────────────────────┐
        ▼                          ▼
   ┌──────────────┐       ┌──────────────┐
   │ Storage Acct │       │ Storage Acct │
   │ Primary      │       │ Secondary    │
   │ Canada Cent. │       │ East US      │
   │ $web         │       │ $web         │
   │ (priority 1) │       │ (priority 2) │
   └──────────────┘       └──────────────┘
```

## Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| CDN service | Front Door Standard (not CDN classic) | CDN classic retired Aug 2025; managed certs expired Apr 2026 |
| Redundancy | LRS (not GRS) | Front Door cache + multi-region origins provide availability |
| Multi-region | Two storage accounts (Canada Central + East US) | Front Door auto-failover if primary goes down |
| Data protection | Soft delete / versioning disabled | Files are version-controlled in Git; avoids accumulated storage costs |
| Storage firewall | Trusted services bypass | Blocks direct access; all traffic forced through Front Door |
| TLS certificates | Front Door managed (free) | Auto-renewing, zero maintenance vs Key Vault-hosted certs |
| DNS zone | Separate resource group (rg-dns-shared) | Preserves nameserver delegation across workload teardowns |
| Health probe | HTTPS protocol | Storage rejects HTTP when secure transfer is required |

## Cost Breakdown (~$37/month)

| Component | Monthly Cost | Notes |
|-----------|-------------|-------|
| Storage (2x LRS, ~1 GB each) | ~$0.04 | Locally redundant, cheapest tier |
| Front Door Standard base fee | ~$35.00 | Fixed hourly fee per profile |
| Front Door data transfer | $0.00 | First 100 GB free in NA/EU |
| Azure DNS zone | $0.50 | Per hosted zone |
| Azure DNS queries | ~$0.40 | Per million queries |
| Log Analytics (30-day retention) | ~$1.00 | Minimal log volume |
| **Total** | **~$37/month** | |

> **Cost tip:** Tear down the workload when not demoing (`terraform destroy` in the workload folder). The DNS zone in rg-dns-shared costs only $0.50/month and preserves your nameserver delegation.

## Project Structure

```
azure-static-site-terraform/
├── bootstrap/                  ← Run ONCE (permanent DNS zone)
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── workload/                   ← Run repeatedly (disposable infrastructure)
│   ├── providers.tf
│   ├── variables.tf
│   ├── resource_group.tf
│   ├── storage_primary.tf
│   ├── storage_secondary.tf
│   ├── frontdoor.tf
│   ├── custom_domain.tf
│   ├── dns_records.tf
│   ├── storage_firewall.tf
│   ├── monitoring.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── site/                       ← Website files (uploaded via CLI)
│   ├── index.html
│   ├── 404.html
│   ├── css/style.css
│   └── js/main.js
├── .gitignore
└── README.md
```

## Prerequisites

- Azure subscription with active billing
- Azure CLI installed (`az --version` ≥ 2.50)
- Terraform installed (`terraform --version` ≥ 1.5)
- Custom domain registered (e.g., mokcloud.site via Namecheap)
- Domain nameservers delegated to Azure DNS (done in bootstrap)

## Deployment Guide

### Phase 1: Bootstrap (one-time DNS zone setup)

```powershell
cd bootstrap

# Create terraform.tfvars from the example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription_id

terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

**After apply, copy the 4 nameservers from the output and paste them into your domain registrar (Namecheap → Domain List → mokcloud.site → Custom DNS).**

Verify delegation:
```powershell
nslookup -type=NS mokcloud.site
```

Wait until the Azure nameservers appear (5-30 minutes).

### Phase 2: Workload (main infrastructure)

```powershell
cd ../workload

# Create terraform.tfvars from the example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in subscription_id and dns_zone_id
# Get dns_zone_id from: cd ../bootstrap && terraform output dns_zone_id

terraform init
terraform plan -out=workload.tfplan
terraform apply workload.tfplan
```

Deployment takes 5-10 minutes (Front Door provisioning across global edge network).

### Phase 3: Upload website files

```powershell
# Grant yourself blob permissions (first time only)
$USER_ID = az ad signed-in-user show --query id -o tsv
$SA_PRI = az storage account show --name <primary-name-from-output> --resource-group rg-staticsite-prod --query id -o tsv
$SA_SEC = az storage account show --name <secondary-name-from-output> --resource-group rg-staticsite-prod --query id -o tsv
az role assignment create --assignee $USER_ID --role "Storage Blob Data Contributor" --scope $SA_PRI
az role assignment create --assignee $USER_ID --role "Storage Blob Data Contributor" --scope $SA_SEC

# Wait 60 seconds for role propagation, then upload to BOTH accounts
az storage blob upload-batch --account-name <primary-name> --source ./site --destination '$web' --auth-mode login --overwrite true
az storage blob upload-batch --account-name <secondary-name> --source ./site --destination '$web' --auth-mode login --overwrite true
```

### Phase 4: Verify

1. Visit `https://mokcloud.site` — should show the site with HTTPS
2. Visit `https://www.mokcloud.site` — same site
3. Visit the direct storage endpoint — should return 403/404 (blocked)
4. Check Front Door metrics in the portal for cache hit rates

### Tear Down (save ~$35/month)

```powershell
# Destroy workload only (preserves DNS zone)
cd workload
terraform destroy

# Full destroy (including DNS — requires Namecheap reconfiguration)
cd ../bootstrap
terraform destroy
```

## Why Front Door Standard (Not Azure CDN Classic)

| Date | Event |
|------|-------|
| Jan 15, 2025 | Azure CDN from Edgio fully retired |
| Aug 15, 2025 | CDN classic blocked new profiles, domains, and managed certificates |
| Apr 14, 2026 | Existing CDN classic managed certificates expired |
| Sep 30, 2027 | Azure CDN Standard from Microsoft (classic) full retirement |

For any new project built after August 2025, Azure Front Door Standard is the only supported CDN option. This project uses Front Door Standard by design, not by limitation.

## Technologies

- **Terraform** — Infrastructure as Code
- **Azure Storage** — Static website hosting (StorageV2, LRS)
- **Azure Front Door Standard** — Global CDN, HTTPS, load balancing
- **Azure DNS** — DNS hosting with alias record support
- **Azure Monitor** — Log Analytics + diagnostic settings
- **Azure Cost Management** — Budget alerts

## Author

**MK (Mokenyu Kezongwe)**
- GitHub: [mokenyujunior-tech](https://github.com/mokenyujunior-tech)
- Portfolio: [mokenyujunior-tech.github.io](https://mokenyujunior-tech.github.io)
- Certifications: AZ-900, MS-900
