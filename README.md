# AER — Azure Estate Report

> Read-only, fully-offline HTML dashboards for your Azure estate — generated from a single PowerShell command.

**AER** is a PowerShell 7 module that connects to Azure with your existing credentials, collects a **read-only** inventory of your tenant through **Azure Resource Graph** and **ARM REST APIs**, and renders a rich, multi-page **self-contained HTML report** you can open straight from disk — no web server, no database, and no internet connection required to view it.

> 🌐 **Português:** see [README.pt-br.md](README.pt-br.md)

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Publish PowerShell Gallery](https://github.com/TrimTechBr/azure-estate-report/actions/workflows/publish-powershell-gallery.yml/badge.svg)](https://github.com/TrimTechBr/azure-estate-report/actions/workflows/publish-powershell-gallery.yml)
[![Read-only](https://img.shields.io/badge/mode-read--only-2ea44f)](#-security--privacy)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#-license)

---

## ✨ Highlights

- **One command, full estate.** `Invoke-AerReport` discovers every subscription you can access and produces a complete report.
- **100% read-only.** AER never creates, changes, or deletes anything in Azure. Safe to run in production.
- **Fully offline output.** The report is plain HTML/CSS/JS with the data embedded — share the folder, open it on an air-gapped machine, attach it to a ticket.
- **Executive XLSX and PDF exports.** The home page includes buttons to download a rich Excel workbook and a share-ready PDF report.
- **Fast.** Collectors run in parallel across the tenant.
- **Modern, navigable UI.** A multi-page SPA-like experience: sidebar navigation, searchable/filterable/resizable tables, contextual accordions, donut/bar charts, and interactive diagrams (topology, peering, VM→DCR→destination) with zoom, pan and PNG export.

## 📊 What's in the report

| Area | Pages |
|------|-------|
| **Assessment** | Overview · Resource Inventory · Cloud Structure (management groups & subscriptions) · Azure Advisor |
| **Compute** | Virtual Machines · Virtual Machine Scale Sets |
| **Databases** | Overview · Relational (incl. SQL-on-VM) · NoSQL · Cache · Analytics · Table Storage |
| **Applications** | Overview · Web / App Services · Functions & Logic Apps · Containers · API & Integration · AKS |
| **Network** | Overview (IP utilization, DNS, balancers) · Virtual Networks (subnets, UDRs, peering diagram) · Load Balancers |
| **Observability** | Coverage Overview · Diagnostic Settings · AMA & Data Collection (VM→DCR→destination diagram) · Inventory (Log Analytics / App Insights) |
| **Policy** | Overview (compliance, assignments by effect) · Exemptions · Remediation |
| **Security** | Defender for Cloud Overview (plan coverage) · Recommendations |
| **Findings** | Cost optimization · Observability recommendations · General (security/config gaps) |

Every data table supports global search, per-column multi-select filters, column show/hide (persisted), column resize, pagination and an expandable detail accordion.

### XLSX and PDF exports

In addition to the offline HTML site, every run creates an `exports/` folder inside `-OutputPath`:

| File | Contents |
|------|----------|
| `exports/aer-report.xlsx` | Excel workbook with a first **Dashboard** sheet, executive KPIs, estate distribution, compute panels, operational signals, and executive/technical tabs for inventory, findings, Advisor, Defender, Policy, data services, applications and collection errors. |
| `exports/aer-report.pdf` | Landscape PDF report with an executive cover, key metrics and printable table pages for inventory, security/cost findings and Azure Advisor recommendations. |

The links are shown on the HTML report home page, both in the top bar and in the export panel. Files are generated locally alongside the report and do not depend on external services.

---

## 🖼️ Output examples

You can generate a local sample report without connecting to Azure:

```powershell
Import-Module ./Aer.psd1 -Force
Invoke-AerReport -SampleData -OutputPath ./output-test/sample -OpenReport
```

### Assessment

| Overview | Inventory |
|----------|-----------|
| ![Assessment overview](assets/images/assessment-overview.png) | ![Resource inventory](assets/images/assessment-inventory.png) |

| Cloud Structure | Azure Advisor |
|-----------------|---------------|
| ![Cloud structure](assets/images/assessment-cloudStructure.png) | ![Azure Advisor](assets/images/assessment-advisor.png) |

### Compute

| Virtual Machines | VM Scale Sets |
|------------------|---------------|
| ![Virtual Machines](assets/images/compute-vm.png) | ![Virtual Machine Scale Sets](assets/images/compute-vmss.png) |

### Databases

| Overview | Relational | NoSQL |
|----------|------------|-------|
| ![Database overview](assets/images/databases-overview.png) | ![Relational databases](assets/images/databases-relational.png) | ![NoSQL databases](assets/images/databases-nosql.png) |

| Cache | Analytics | Table Storage |
|-------|-----------|---------------|
| ![Cache](assets/images/databases-cache.png) | ![Analytics](assets/images/databases-analytics.png) | ![Table Storage](assets/images/databases-tableStorage.png) |

### Applications

| Overview | Web / App Services | Functions & Logic |
|----------|--------------------|-------------------|
| ![Applications overview](assets/images/applications-overview.png) | ![Web and App Services](assets/images/applications-webapp.png) | ![Functions and Logic Apps](assets/images/applications-function.png) |

| Containers | API & Integration | AKS |
|------------|-------------------|-----|
| ![Containers](assets/images/applications-container.png) | ![API and Integration](assets/images/applications-api.png) | ![AKS clusters](assets/images/applications-aks.png) |

### Network

| Overview | Virtual Networks | Load Balancers |
|----------|------------------|----------------|
| ![Network overview](assets/images/network-overview.png) | ![Virtual Networks](assets/images/network-vnet.png) | ![Load Balancers](assets/images/network-lbs.png) |

### Observability

| Overview | Diagnostic Settings |
|----------|---------------------|
| ![Observability overview](assets/images/observability-overview.png) | ![Diagnostic Settings](assets/images/observability-diagSettings.png) |

| AMA & Data Collection | Inventory |
|-----------------------|-----------|
| ![AMA and Data Collection](assets/images/observability-ama-dcr.png) | ![Observability inventory](assets/images/observability-inventory.png) |

### Policy & Security

| Policy Overview | Exemptions | Remediation |
|-----------------|------------|-------------|
| ![Policy overview](assets/images/policy-overview.png) | ![Policy exemptions](assets/images/policy-exemption.png) | ![Policy remediation](assets/images/policy-remediation.png) |

| Security Overview | Security Recommendations |
|-------------------|--------------------------|
| ![Security overview](assets/images/security-overview.png) | ![Security recommendations](assets/images/security-recommendation.png) |

### Findings

| General | Cost | Observability |
|---------|------|---------------|
| ![General findings](assets/images/findings-general.png) | ![Cost findings](assets/images/findings-cost.png) | ![Observability findings](assets/images/findings-observability.png) |

---

## ✅ Requirements

- **PowerShell 7.0+** (`pwsh`)
- **Az PowerShell modules**: `Az.Accounts`, `Az.ResourceGraph`
- An **authenticated Azure session** (`Connect-AzAccount`)
- **Azure RBAC** on the target scope:
  - `Reader` — minimum, for inventory and most pages
  - `Monitoring Reader` — recommended, for richer observability data
  - To read App Service settings (App Insights coverage) the identity needs `Microsoft.Web/sites/config/list/Action` (e.g. *Website Contributor*); with plain *Reader* that signal is skipped gracefully.

## 📦 Installation

```powershell
# Clone the repository
git clone https://github.com/TrimTechBr/azure-state-report.git
cd azure-state-report

# Install the Azure dependencies (once)
Install-Module Az.Accounts, Az.ResourceGraph -Scope CurrentUser

# Import the module
Import-Module ./Aer.psd1
```

## 🚀 Quick start

```powershell
# 1) Sign in to Azure
Connect-AzAccount

# 2) Generate the report for every subscription you can access
Invoke-AerReport -OpenReport
```

The report is written to `.\aer-report\index.html` (override with `-OutputPath`). `-OpenReport` opens it in your default browser when it's ready.

Exports are written beside it: `.\aer-report\exports\aer-report.xlsx` and `.\aer-report\exports\aer-report.pdf`.

To validate the layout without Azure access, use the built-in sample dataset:

```powershell
Invoke-AerReport -SampleData -OutputPath .\aer-sample -OpenReport
```

```
  AER · Azure Estate Report v0.1.0
  ──────────────────────────────────────────────
  ▶ Resolving Azure context…
  ✓ Signed in as you@contoso.com  tenant: contoso.onmicrosoft.com
  ✓ 21 subscription(s) in scope
  ▶ Collecting estate data…  21 collectors · parallelism 4
  ✓ Collected all 21 data sets
  ▶ Rendering HTML report…
  ✓ Report generated  C:\...\aer-report\index.html
  ✓ Excel export      C:\...\aer-report\exports\aer-report.xlsx
  ✓ PDF export        C:\...\aer-report\exports\aer-report.pdf

  Summary
  ──────────────────────────────────────
    Subscriptions                    21
    Resource groups                 312
    Resources                     4,096
    ...
  ✓ Done.
```

## 🛠️ Usage

```powershell
# All subscriptions in the current context
Invoke-AerReport

# Custom output folder + open when done
Invoke-AerReport -OutputPath C:\Reports\Contoso -OpenReport

# Only specific subscriptions
Invoke-AerReport -SubscriptionId '00000000-0000-0000-0000-000000000000','1111...'

# Exclude subscriptions by name, with more parallelism
Invoke-AerReport -ExcludeSubscriptionName 'Sandbox','Lab' -MaxParallelCollectors 8

# Generate a layout/demo report with built-in sample data
Invoke-AerReport -SampleData -OutputPath .\aer-sample -OpenReport

# Capture a summary object for automation
$r = Invoke-AerReport -PassThru
$r.Resources; $r.IndexHtml; $r.ExcelWorkbook; $r.PdfReport
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-OutputPath` | string | `.\aer-report` | Folder for the HTML report (created if missing). Entry point: `index.html`. |
| `-SubscriptionId` | string[] | *(all)* | One or more subscription IDs to include. |
| `-ExcludeSubscriptionName` | string[] | *(none)* | Subscription display names to exclude (exact, case-insensitive). |
| `-MaxParallelCollectors` | int (1–10) | `4` | Number of collectors to run concurrently. |
| `-SampleData` | switch | off | Generate a rich fake-data report without connecting to Azure. Useful for screenshots, demos and layout validation. |
| `-OpenReport` | switch | off | Open the report in the browser when finished. |
| `-PassThru` | switch | off | Return a summary object (paths, counts, duration). |

Full help is available in the console:

```powershell
Get-Help Invoke-AerReport -Full
Get-Help Invoke-AerReport -Examples
```

---

## 🔒 Security & privacy

- **Read-only by design.** AER only issues read/list/query calls (Resource Graph + ARM GET / `POST …/summarize|queryResults|list`). It performs no write operations.
- **Your data stays with you.** Collection happens locally with your credentials; the resulting HTML embeds the data in `assets/data.js`. Nothing is uploaded anywhere.
- **Offline.** The generated report has no external dependencies and works under `file://`.
- ⚠️ The report contains environment metadata (resource names, IDs, configuration). Treat the output folder as you would any infrastructure inventory.

## 🧱 Architecture

```
Aer.psd1 / Aer.psm1          Module manifest + loader (dot-sources everything)
Public/Invoke-AerReport.ps1  Orchestrator (context → parallel collection → render)
Core/ResourceGraph.ps1       ARG query helper, columnar-safe row expander, ARM batch, aggregators
Collectors/*.ps1             One Get-Aer* function per domain → returns a plain object
Renderer/
  Dashboard.ps1              Page registry, sidebar nav, per-page HTML scaffolds, document shell
  Export.ps1                 Offline XLSX/PDF generation and native OpenXML/PDF helpers
  Assets/Script.ps1          The single-IIFE vanilla-JS app (tables, charts, diagrams)
  Assets/Style.ps1           The stylesheet
```

The flow: **collectors** query Azure and return PowerShell objects → the orchestrator serializes them into `window.AerData` → the **renderer** emits one HTML file per page plus shared `assets/` (style.css, app.js, data.js) → the exporter creates `exports/aer-report.xlsx` and `exports/aer-report.pdf`. The JS reads `AerData` and builds the UI on the client.

---

## 🤝 How to contribute

Contributions are very welcome — new collectors, pages, checks, fixes and docs.

### Development setup

```powershell
git clone https://github.com/TrimTechBr/azure-state-report.git
cd azure-state-report
Install-Module Az.Accounts, Az.ResourceGraph -Scope CurrentUser
Connect-AzAccount
Import-Module ./Aer.psd1 -Force
Invoke-AerReport -OutputPath ./output-test   # ./output-test is git-ignored
```

> 💡 PowerShell caches imported modules. After editing any `.ps1`, re-run `Import-Module ./Aer.psd1 -Force` (or use a fresh terminal) before regenerating.

### Branching & PR flow

1. Branch off `develop` (e.g. `feature-xxxx` / `fix-...`).
2. Make focused commits.
3. Open a Pull Request into `develop`. Keep PRs scoped to one feature/fix.
4. Describe what changed and how you validated it.

### Adding a new domain section (the pattern)

1. **Collector** — create `Collectors/MyThing.ps1` with `Get-AerMyThing` returning a `[pscustomobject]`.
2. **Wire it** in `Public/Invoke-AerReport.ps1` (four touch points): the `$collectors` array, the `$collectorFile` switch, the `$data` switch, and the `$reportData` key.
3. **Page** — in `Renderer/Dashboard.ps1`: add a `$script:AerPages` entry, a `navItem` in the sidebar, and an HTML scaffold in `Get-AerPageContent`.
4. **Render** — in `Renderer/Assets/Script.ps1`: read `d.myThing` and build the UI (reuse `initDataTable`, `renderDonut`, `renderBars`, `setHeader`, `kvGrid`, the cell-pill helpers).

### Conventions & gotchas (learned the hard way)

- **Target PowerShell 7**; use `CancellationToken`-friendly, read-only Azure calls only.
- **ARG columnar quirk:** `Search-AzGraph` may intermittently return one *columnar* object instead of per-row objects. For scalar-only `project` queries, wrap results with `Expand-AerRows` (in `Core/ResourceGraph.ps1`). Don't use it on queries that legitimately return array-valued columns.
- **Management-group-scoped resources** (e.g. Policy assignments/exemptions) are **dropped** by a subscription-scoped query — query the ARG REST endpoint **without** a `subscriptions` filter (and `resultFormat=objectArray`) when you need MG scope.
- **KQL reserved words:** don't use `kind` as a `project` output column (alias it, e.g. `dcrKind = tostring(kind)`).
- **PowerShell automatic vars:** never reuse `$pid` or `$host` as your own variables (read-only).
- **JSON arrays:** `ConvertTo-Json` unwraps single-element arrays — the JS side normalizes lists with `toArr()`; PS7 `ConvertFrom-Json` auto-parses ISO dates to `[datetime]` (format defensively).
- **ARM batch:** use `Invoke-AerArmBatch` (≤20 requests/call) for per-resource REST (e.g. diagnostic settings).
- **Validate before committing:**
  ```powershell
  [System.Management.Automation.Language.Parser]::ParseFile('path\to\file.ps1',[ref]$null,[ref]([ref]$errs).Value)
  Import-Module ./Aer.psd1 -Force; Invoke-AerReport -OutputPath ./output-test
  ```

---

## 🗺️ Roadmap

- More Network pages (NSG rules, route tables, Azure Firewall, public IPs)
- Per-category detail pages for additional sections
- Publish to the PowerShell Gallery
- Optional CSV export of the collected data

## 📄 License

MIT © AER contributors. See [LICENSE](LICENSE).
