$script:AerSvgLogo = @'
<svg width="32" height="32" viewBox="0 0 38 38" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="38" height="38" rx="8" fill="url(#aer-grad)"/>
  <defs>
    <linearGradient id="aer-grad" x1="0" y1="0" x2="38" y2="38">
      <stop offset="0%" stop-color="#0078d4"/>
      <stop offset="100%" stop-color="#50e6ff"/>
    </linearGradient>
  </defs>
  <path d="M10 24a4 4 0 01-.5-7.97A6 6 0 0121 15a4.5 4.5 0 016 4.25A3.75 3.75 0 0127 27H10z" fill="white" opacity=".95"/>
  <path d="M18 17l-3 5h3.5l-1 5 5-7h-3.5l1-3H18z" fill="#0078d4"/>
</svg>
'@

# Page registry: key → file name + topbar title
$script:AerPages = [ordered]@{
    overview       = @{ File = 'index.html';           Title = 'Overview' }
    inventory      = @{ File = 'inventory.html';       Title = 'Resource Inventory' }
    cloudstructure = @{ File = 'cloud-structure.html'; Title = 'Cloud Structure' }
    advisor        = @{ File = 'advisor.html';         Title = 'Azure Advisor' }
    virtualmachines= @{ File = 'virtual-machines.html'; Title = 'Virtual Machines' }
    vmscalesets    = @{ File = 'vmss.html';            Title = 'Virtual Machine Scale Sets' }
    databases      = @{ File = 'databases.html';       Title = 'Database Services' }
    relational     = @{ File = 'relational-databases.html'; Title = 'Relational Databases' }
    nosql          = @{ File = 'nosql-databases.html';  Title = 'NoSQL Databases' }
    cache          = @{ File = 'cache.html';            Title = 'Cache' }
    analytics      = @{ File = 'analytics.html';        Title = 'Analytics' }
    tablestorage   = @{ File = 'table-storage.html';    Title = 'Table Storage' }
    applications   = @{ File = 'applications.html';     Title = 'Application Services' }
    webapps        = @{ File = 'web-app-services.html'; Title = 'Web / App Services' }
    functions      = @{ File = 'functions-logic.html';  Title = 'Functions & Logic Apps' }
    containers     = @{ File = 'containers.html';       Title = 'Containers' }
    integration    = @{ File = 'api-integration.html';  Title = 'API & Integration' }
    aks            = @{ File = 'aks-clusters.html';     Title = 'AKS Clusters' }
    network        = @{ File = 'network.html';          Title = 'Network' }
    vnets          = @{ File = 'vnets.html';            Title = 'Virtual Networks' }
    loadbalancers  = @{ File = 'load-balancers.html';   Title = 'Load Balancers' }
    observability  = @{ File = 'observability.html';    Title = 'Observability' }
    diagsettings   = @{ File = 'diagnostic-settings.html'; Title = 'Diagnostic Settings' }
    amadcr         = @{ File = 'ama-dcr.html';           Title = 'AMA & Data Collection' }
    obsinventory   = @{ File = 'observability-inventory.html'; Title = 'Observability Inventory' }
    policy         = @{ File = 'policy.html';            Title = 'Policy' }
    policyexemptions = @{ File = 'policy-exemptions.html'; Title = 'Policy Exemptions' }
    policyremediation = @{ File = 'policy-remediation.html'; Title = 'Policy Remediation' }
    securityoverview = @{ File = 'security-overview.html'; Title = 'Security' }
    securityrecommendations = @{ File = 'security-recommendations.html'; Title = 'Security Recommendations' }
    security       = @{ File = 'security.html';        Title = 'General Findings' }
    cost           = @{ File = 'cost.html';            Title = 'Cost Optimization' }
    obsfindings    = @{ File = 'observability-findings.html'; Title = 'Observability Recommendations' }
}

function Get-AerSidebarHtml {
    param([string] $Active, $Meta)

    $pages = $script:AerPages
    function navItem($key, $icon, $label, $badge) {
        $active = if ($key -eq $Active) { ' active' } else { '' }
        $badgeHtml = if ($badge) { "<span class=`"nav-badge $badge`">0</span>" } else { '' }
        "      <a class=`"nav-item$active`" data-page=`"$key`" href=`"$($pages[$key].File)`" title=`"$label`">`n" +
        "        <span class=`"nav-icon`">$icon</span><span class=`"nav-label`">$label</span>$badgeHtml`n      </a>"
    }

    @"
<aside class="sidebar">
  <div class="sidebar-brand">
    $($script:AerSvgLogo)
    <div class="sidebar-brand-text">
      <div class="brand-name">Azure Estate Report</div>
      <div class="brand-sub">AER · Read-only</div>
    </div>
  </div>

  <div class="sidebar-search">
    <div class="sidebar-search-box">
      <span class="sidebar-search-icon">&#128269;</span>
      <input type="text" id="menu-search" placeholder="Search menu..." autocomplete="off"/>
    </div>
    <button class="sidebar-toggle" id="sidebar-toggle" type="button" title="Collapse sidebar" aria-label="Toggle sidebar">&#9776;</button>
  </div>

  <nav class="sidebar-nav" id="sidebar-nav">
    <div class="nav-group" data-group="assessment">
      <button class="nav-section" type="button"><span class="nav-section-label">Assessment</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'overview'  '📊' 'Overview' $null)
$(navItem 'inventory' '📦' 'Inventory' $null)
$(navItem 'cloudstructure' '🏛️' 'Cloud Structure' $null)
$(navItem 'advisor'  '⭐' 'Advisor' $null)
      </div>
    </div>
    <div class="nav-group" data-group="compute">
      <button class="nav-section" type="button"><span class="nav-section-label">Compute</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'virtualmachines' '🖥️' 'Virtual Machines' $null)
$(navItem 'vmscalesets' '🧩' 'VM Scale Sets' $null)
      </div>
    </div>
    <div class="nav-group" data-group="databases">
      <button class="nav-section" type="button"><span class="nav-section-label">Databases</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'databases' '🛢️' 'Overview' $null)
$(navItem 'relational' '🗄️' 'Relational' $null)
$(navItem 'nosql' '🌐' 'NoSQL' $null)
$(navItem 'cache' '⚡' 'Cache' $null)
$(navItem 'analytics' '📈' 'Analytics' $null)
$(navItem 'tablestorage' '🧱' 'Table Storage' $null)
      </div>
    </div>
    <div class="nav-group" data-group="applications">
      <button class="nav-section" type="button"><span class="nav-section-label">Applications</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'applications' '🚀' 'Overview' $null)
$(navItem 'webapps' '🌐' 'Web / App Services' $null)
$(navItem 'functions' '⚙️' 'Functions & Logic' $null)
$(navItem 'containers' '📦' 'Containers' $null)
$(navItem 'integration' '🔌' 'API & Integration' $null)
$(navItem 'aks' '☸' 'AKS Clusters' $null)
      </div>
    </div>
    <div class="nav-group" data-group="network">
      <button class="nav-section" type="button"><span class="nav-section-label">Network</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'network' '🔗' 'Overview' $null)
$(navItem 'vnets' '🔷' 'Virtual Networks' $null)
$(navItem 'loadbalancers' '⚖️' 'Load Balancers' $null)
      </div>
    </div>
    <div class="nav-group" data-group="observability">
      <button class="nav-section" type="button"><span class="nav-section-label">Observability</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'observability' '📈' 'Overview' $null)
$(navItem 'diagsettings' '🩺' 'Diagnostic Settings' $null)
$(navItem 'amadcr' '🛰️' 'AMA & Data Collection' $null)
$(navItem 'obsinventory' '🗂️' 'Inventory' $null)
      </div>
    </div>
    <div class="nav-group" data-group="policy">
      <button class="nav-section" type="button"><span class="nav-section-label">Policy</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'policy' '⚖️' 'Overview' $null)
$(navItem 'policyexemptions' '🪪' 'Exemptions' $null)
$(navItem 'policyremediation' '🔧' 'Remediation' $null)
      </div>
    </div>
    <div class="nav-group" data-group="securitysection">
      <button class="nav-section" type="button"><span class="nav-section-label">Security</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'securityoverview' '🔐' 'Overview' $null)
$(navItem 'securityrecommendations' '🛡️' 'Recommendations' $null)
      </div>
    </div>
    <div class="nav-group" data-group="findings">
      <button class="nav-section" type="button"><span class="nav-section-label">Findings</span><span class="nav-section-chevron">&#9662;</span></button>
      <div class="nav-group-items">
$(navItem 'security' '📋' 'General' 'bad')
$(navItem 'cost'     '💰' 'Cost' 'warn')
$(navItem 'obsfindings' '📈' 'Observability' 'warn')
      </div>
    </div>
    <div class="nav-empty" id="nav-empty" style="display:none">No menu items match.</div>
  </nav>

  <div class="sidebar-footer">
    <div class="sidebar-tenant-label">Tenant</div>
    <div class="sidebar-tenant-val">$($Meta.TenantDomain)</div>
    <div class="sidebar-version">AER v$($Meta.ModuleVersion) · $(([math]::Round($Meta.DurationMs / 1000, 1)))s</div>
  </div>
</aside>
"@
}

function Get-AerServicePageHtml {
    param([string] $Prefix, [string] $SearchPlaceholder)
    @"
      <div class="page-header" id="$Prefix-header"></div>

      <div class="section-title">Summary</div>
      <div class="stat-tiles" id="$Prefix-tiles"></div>

      <div class="section-title">Resources</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="$Prefix-global-search" placeholder="$SearchPlaceholder"/>
          </div>
          <div class="table-active-filters" id="$Prefix-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="$Prefix-table">
            <colgroup id="$Prefix-colgroup"></colgroup>
            <thead id="$Prefix-thead"></thead>
            <tbody id="$Prefix-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="$Prefix-pager"></div>
      </div>
"@
}

function Get-AerOverviewPageHtml {
    param([string] $Prefix)
    @"
      <div class="page-header" id="$Prefix-header"></div>

      <div class="section-title">Summary</div>
      <div class="stat-tiles" id="$Prefix-tiles"></div>

      <div class="section-title">Distribution</div>
      <div class="charts-row">
        <div class="card"><h3>By Category</h3><div id="$Prefix-chart-category"></div></div>
        <div class="card"><h3>Top Resource Types</h3><div id="$Prefix-chart-type"></div></div>
        <div class="card"><h3>By Region</h3><div id="$Prefix-chart-region"></div></div>
      </div>
"@
}

function Get-AerPageContent {
    param([string] $Page)

    switch ($Page) {
        'overview' {
@'
      <div id="err-banner"></div>

      <div class="section-title">Executive Summary</div>
      <div class="kpi-grid" id="kpi-grid"></div>

      <div class="section-title">Resource Inventory</div>
      <div class="charts-row">
        <div class="card"><h3>Resources by Subscription</h3><div id="chart-by-sub"></div></div>
        <div class="card"><h3>Top Resource Types</h3><div id="chart-by-type"></div></div>
        <div class="card"><h3>Distribution by Region</h3><div id="chart-by-region"></div></div>
      </div>

      <div class="section-title">Azure Advisor</div>
      <div class="card" style="margin-bottom:26px">
        <div class="advisor-header">
          <h3>Recommendations by Category</h3>
          <span class="high-impact-badge" id="advisor-high-badge"></span>
        </div>
        <div class="advisor-cards" id="advisor-grid"></div>
      </div>

      <div class="section-title">Findings</div>
      <div class="bottom-row">
        <div class="card">
          <h3>&#9888; Top Security Gaps</h3>
          <div id="security-list-ov"></div>
        </div>
        <div class="card">
          <h3>&#128176; Cost Waste Opportunities</h3>
          <div id="cost-list-ov"></div>
        </div>
      </div>
'@
        }
        'inventory' {
@'
      <div class="page-header" id="inv-header"></div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="res-global-search" placeholder="Search all resources..."/>
          </div>
          <div class="table-active-filters" id="res-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="res-table">
            <colgroup id="res-colgroup"></colgroup>
            <thead id="res-thead"></thead>
            <tbody id="res-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="res-pager"></div>
      </div>
'@
        }
        'cloudstructure' {
@'
      <div class="page-header" id="cs-header"></div>
      <div class="cs-grid">
        <div class="card">
          <h3>🏛️ Management Groups</h3>
          <div class="table-scroll">
            <table class="aer-table simple">
              <thead><tr><th>ID</th><th>Name</th><th>Parent Management Group</th></tr></thead>
              <tbody id="mg-tbody"></tbody>
            </table>
          </div>
          <div class="pager" id="mg-pager"></div>
        </div>
        <div class="card">
          <h3>&#9729; Subscriptions</h3>
          <div class="table-scroll">
            <table class="aer-table simple">
              <thead><tr><th>ID</th><th>Name</th><th>Management Group</th></tr></thead>
              <tbody id="sub-tbody"></tbody>
            </table>
          </div>
          <div class="pager" id="sub-pager"></div>
        </div>
      </div>

      <div class="section-title">Hierarchy Diagram</div>
      <div class="card">
        <div class="tree-toolbar">
          <div class="tree-legend">
            <span class="tree-legend-item"><span class="tree-dot root"></span>Tenant Root</span>
            <span class="tree-legend-item"><span class="tree-dot mg"></span>Management Group</span>
            <span class="tree-legend-item"><span class="tree-dot sub"></span>Subscription</span>
          </div>
          <div class="tree-controls">
            <button class="tree-btn" id="mg-zoom-out" title="Zoom out">&#8722;</button>
            <span class="tree-zoom-label" id="mg-zoom-label">100%</span>
            <button class="tree-btn" id="mg-zoom-in" title="Zoom in">&#43;</button>
            <button class="tree-btn" id="mg-zoom-reset" title="Reset zoom">Reset</button>
            <button class="tree-btn primary" id="mg-export-png" title="Download as PNG image">&#8681; PNG</button>
            <button class="tree-btn" id="mg-export-svg" title="Download as SVG vector">&#8681; SVG</button>
          </div>
        </div>
        <div class="tree-wrap" id="mg-tree-wrap"></div>
      </div>
'@
        }
        'security' {
@'
      <div class="page-header" id="sec-header"></div>
      <div class="section-title">General Findings</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="secf-global-search" placeholder="Search findings..."/></div>
          <div class="table-active-filters" id="secf-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="secf-table"><colgroup id="secf-colgroup"></colgroup><thead id="secf-thead"></thead><tbody id="secf-tbody"></tbody></table></div>
        <div class="pager" id="secf-pager"></div>
      </div>
'@
        }
        'cost' {
@'
      <div class="page-header" id="cost-header"></div>
      <div class="section-title">Cost Findings</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="costf-global-search" placeholder="Search findings..."/></div>
          <div class="table-active-filters" id="costf-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="costf-table"><colgroup id="costf-colgroup"></colgroup><thead id="costf-thead"></thead><tbody id="costf-tbody"></tbody></table></div>
        <div class="pager" id="costf-pager"></div>
      </div>
'@
        }
        'obsfindings' {
@'
      <div class="page-header" id="obsf-header"></div>
      <div class="section-title">Observability Recommendations</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="obsf-global-search" placeholder="Search recommendations..."/></div>
          <div class="table-active-filters" id="obsf-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="obsf-table"><colgroup id="obsf-colgroup"></colgroup><thead id="obsf-thead"></thead><tbody id="obsf-tbody"></tbody></table></div>
        <div class="pager" id="obsf-pager"></div>
      </div>
'@
        }
        'advisor' {
@'
      <div class="page-header" id="adv-header"></div>
      <div class="card" style="margin-bottom:16px">
        <div class="advisor-header">
          <h3>Recommendations by Category</h3>
          <span class="high-impact-badge" id="advisor-high-badge-pg"></span>
        </div>
        <div class="advisor-cards" id="advisor-grid-pg"></div>
      </div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="adv-global-search" placeholder="Search all recommendations..."/>
          </div>
          <div class="table-active-filters" id="adv-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="adv-table">
            <colgroup id="adv-colgroup"></colgroup>
            <thead id="adv-thead"></thead>
            <tbody id="adv-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="adv-pager"></div>
      </div>
'@
        }
        'virtualmachines' {
@'
      <div class="page-header" id="vm-header"></div>

      <div class="section-title">Compute Summary</div>
      <div class="stat-tiles" id="vm-tiles"></div>

      <div class="section-title">Virtual Machines</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="vm-global-search" placeholder="Search all VMs..."/>
          </div>
          <div class="table-active-filters" id="vm-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="vm-table">
            <colgroup id="vm-colgroup"></colgroup>
            <thead id="vm-thead"></thead>
            <tbody id="vm-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="vm-pager"></div>
      </div>
'@
        }
        'vmscalesets' {
@'
      <div class="page-header" id="vmss-header"></div>

      <div class="section-title">Compute Summary</div>
      <div class="stat-tiles" id="vmss-tiles"></div>

      <div class="section-title">Virtual Machine Scale Sets</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="vmss-global-search" placeholder="Search all scale sets..."/>
          </div>
          <div class="table-active-filters" id="vmss-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="vmss-table">
            <colgroup id="vmss-colgroup"></colgroup>
            <thead id="vmss-thead"></thead>
            <tbody id="vmss-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="vmss-pager"></div>
      </div>
'@
        }
        'databases' {
@'
      <div class="page-header" id="db-header"></div>

      <div class="section-title">Database Estate</div>
      <div class="stat-tiles" id="db-tiles"></div>

      <div class="section-title">Distribution</div>
      <div class="charts-row">
        <div class="card"><h3>Services by Category</h3><div id="db-chart-category"></div></div>
        <div class="card"><h3>Top Service Types</h3><div id="db-chart-type"></div></div>
        <div class="card"><h3>Services by Region</h3><div id="db-chart-region"></div></div>
      </div>

      <div class="section-title">Families</div>
      <div class="bottom-row">
        <div class="card"><h3>Cosmos DB by API</h3><div id="db-chart-cosmos"></div></div>
        <div class="card"><h3>Azure Cache for Redis by Tier</h3><div id="db-chart-redis"></div></div>
      </div>
'@
        }
        'relational' {
@'
      <div class="page-header" id="rel-header"></div>

      <div class="section-title">Relational Services</div>
      <div class="stat-tiles" id="rel-tiles"></div>

      <div class="section-title">Resources</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="rel-global-search" placeholder="Search relational resources..."/>
          </div>
          <div class="table-active-filters" id="rel-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="rel-table">
            <colgroup id="rel-colgroup"></colgroup>
            <thead id="rel-thead"></thead>
            <tbody id="rel-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="rel-pager"></div>
      </div>
'@
        }
        'nosql'        { Get-AerServicePageHtml -Prefix 'nosql'     -SearchPlaceholder 'Search NoSQL resources...' }
        'cache'        { Get-AerServicePageHtml -Prefix 'cache'     -SearchPlaceholder 'Search cache resources...' }
        'analytics'    { Get-AerServicePageHtml -Prefix 'analytics' -SearchPlaceholder 'Search analytics resources...' }
        'tablestorage' { Get-AerServicePageHtml -Prefix 'table'     -SearchPlaceholder 'Search storage accounts...' }
        'applications' {
@'
      <div class="page-header" id="app-header"></div>

      <div class="section-title">Application Estate</div>
      <div class="stat-tiles" id="app-tiles"></div>

      <div class="section-title">Distribution</div>
      <div class="charts-row">
        <div class="card"><h3>Services by Category</h3><div id="app-chart-category"></div></div>
        <div class="card"><h3>Top Service Types</h3><div id="app-chart-type"></div></div>
        <div class="card"><h3>Services by Region</h3><div id="app-chart-region"></div></div>
      </div>

      <div class="section-title">Families</div>
      <div class="bottom-row">
        <div class="card"><h3>AKS by Kubernetes Version</h3><div id="app-chart-aks"></div></div>
        <div class="card"><h3>App Service Plans by Tier</h3><div id="app-chart-plans"></div></div>
      </div>
'@
        }
        'webapps'     { Get-AerServicePageHtml -Prefix 'webapps'     -SearchPlaceholder 'Search web / app services...' }
        'functions'   { Get-AerServicePageHtml -Prefix 'functions'   -SearchPlaceholder 'Search functions & logic apps...' }
        'containers'  { Get-AerServicePageHtml -Prefix 'containers'  -SearchPlaceholder 'Search container services...' }
        'integration' { Get-AerServicePageHtml -Prefix 'integration' -SearchPlaceholder 'Search API & integration...' }
        'aks'         { Get-AerServicePageHtml -Prefix 'aks'         -SearchPlaceholder 'Search AKS clusters...' }
        'network' {
@'
      <div class="page-header" id="network-header"></div>

      <div class="section-title">Resource Counts</div>
      <div class="stat-tiles" id="network-tiles"></div>

      <div class="section-title">Insights</div>
      <div class="charts-row">
        <div class="card"><h3>IP Address Utilization</h3><div id="network-chart-ip"></div></div>
        <div class="card"><h3>DNS Zones &#8212; Public vs Private</h3><div id="network-chart-dns"></div></div>
        <div class="card"><h3>Applications per Balancer Type</h3><div id="network-chart-balancers"></div></div>
      </div>
'@
        }
        'vnets' {
@'
      <div class="page-header" id="vnet-header"></div>

      <div class="section-title">Virtual Networks</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="vnet-global-search" placeholder="Search virtual networks..."/>
          </div>
          <div class="table-active-filters" id="vnet-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="vnet-table">
            <colgroup id="vnet-colgroup"></colgroup>
            <thead id="vnet-thead"></thead>
            <tbody id="vnet-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="vnet-pager"></div>
      </div>

      <div class="section-title">VNet Peering Diagram</div>
      <div class="card">
        <div class="graph-toolbar">
          <div class="graph-filters">
            <button class="graph-filter-btn" id="vnet-f-sub" type="button">&#9662; Subscription</button>
            <button class="graph-filter-btn" id="vnet-f-rg" type="button">&#9662; Resource Group</button>
            <button class="graph-filter-btn" id="vnet-f-vnet" type="button">&#9662; VNet</button>
            <span class="table-active-filters" id="vnet-filter-tags"></span>
          </div>
          <div class="tree-controls">
            <button class="tree-btn" id="vnet-zoom-out" title="Zoom out">&#8722;</button>
            <span class="tree-zoom-label" id="vnet-zoom-label">100%</span>
            <button class="tree-btn" id="vnet-zoom-in" title="Zoom in">&#43;</button>
            <button class="tree-btn" id="vnet-zoom-reset" title="Reset zoom">Reset</button>
            <button class="tree-btn" id="vnet-download" title="Download PNG">&#11015; PNG</button>
          </div>
        </div>
        <div class="graph-wrap" id="vnet-peering-graph"></div>
        <div class="graph-legend">
          <span class="graph-legend-item"><span class="graph-line gw"></span>Gateway transit / remote gateways</span>
          <span class="graph-legend-item"><span class="graph-line"></span>Standard peering</span>
        </div>
      </div>
'@
        }
        'loadbalancers' {
@'
      <div class="page-header" id="lb-header"></div>

      <div class="section-title">Summary</div>
      <div class="stat-tiles" id="lb-tiles"></div>

      <div class="section-title">Load Balancers</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="lb-global-search" placeholder="Search load balancers..."/>
          </div>
          <div class="table-active-filters" id="lb-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="lb-table">
            <colgroup id="lb-colgroup"></colgroup>
            <thead id="lb-thead"></thead>
            <tbody id="lb-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="lb-pager"></div>
      </div>
'@
        }
        'observability' {
@'
      <div class="page-header" id="obs-header"></div>

      <div class="section-title">Monitoring Coverage</div>
      <div class="stat-tiles" id="obs-kpis"></div>

      <div class="section-title">Coverage Analysis</div>
      <div class="charts-row">
        <div class="card"><h3>Diagnostic Settings Coverage by Subscription</h3><div id="obs-chart-cov-sub"></div></div>
        <div class="card"><h3>Top Resource Types Without Diagnostic Settings</h3><div id="obs-chart-nodiag"></div></div>
      </div>

      <div class="section-title">Resource Counts</div>
      <div class="stat-tiles" id="obs-tiles"></div>
'@
        }
        'diagsettings' {
@'
      <div class="page-header" id="diag-header"></div>

      <div class="section-title">Diagnostic Settings Coverage</div>
      <div class="stat-tiles" id="diag-cards"></div>

      <div class="section-title">Resources</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search">
            <span class="table-search-icon">&#128269;</span>
            <input type="text" id="diag-global-search" placeholder="Search resources..."/>
          </div>
          <div class="table-active-filters" id="diag-active-filters"></div>
        </div>
        <div class="table-scroll">
          <table class="aer-table" id="diag-table">
            <colgroup id="diag-colgroup"></colgroup>
            <thead id="diag-thead"></thead>
            <tbody id="diag-tbody"></tbody>
          </table>
        </div>
        <div class="pager" id="diag-pager"></div>
      </div>
'@
        }
        'amadcr' {
@'
      <div class="page-header" id="dcr-header"></div>

      <div class="section-title">Data Collection</div>
      <div class="stat-tiles" id="dcr-cards"></div>

      <div class="section-title">VM &#8594; DCR &#8594; Destination</div>
      <div class="card">
        <div class="graph-toolbar">
          <div class="graph-filters">
            <button class="graph-filter-btn" id="dcr-f-sub" type="button">&#9662; Subscription</button>
            <button class="graph-filter-btn" id="dcr-f-rg" type="button">&#9662; Resource Group</button>
            <button class="graph-filter-btn" id="dcr-f-machine" type="button">&#9662; Machine</button>
            <button class="graph-filter-btn" id="dcr-f-dcr" type="button">&#9662; DCR</button>
            <span class="table-active-filters" id="dcr-filter-tags"></span>
          </div>
          <div class="tree-controls">
            <button class="tree-btn" id="dcr-zoom-out" title="Zoom out">&#8722;</button>
            <span class="tree-zoom-label" id="dcr-zoom-label">100%</span>
            <button class="tree-btn" id="dcr-zoom-in" title="Zoom in">&#43;</button>
            <button class="tree-btn" id="dcr-zoom-reset" title="Reset zoom">Reset</button>
            <button class="tree-btn" id="dcr-download" title="Download PNG">&#11015; PNG</button>
          </div>
        </div>
        <div class="graph-wrap" id="dcr-graph"></div>
        <div class="graph-legend">
          <span class="graph-legend-item"><span class="graph-dot" style="background:#0ea5e9"></span>VM / Arc machine</span>
          <span class="graph-legend-item"><span class="graph-dot" style="background:#a78bfa"></span>Data Collection Rule</span>
          <span class="graph-legend-item"><span class="graph-dot" style="background:#22c55e"></span>Destination</span>
        </div>
      </div>

      <div class="section-title">Data Collection Rules</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="dcrtab-global-search" placeholder="Search DCRs..."/></div>
          <div class="table-active-filters" id="dcrtab-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="dcrtab-table"><colgroup id="dcrtab-colgroup"></colgroup><thead id="dcrtab-thead"></thead><tbody id="dcrtab-tbody"></tbody></table></div>
        <div class="pager" id="dcrtab-pager"></div>
      </div>

      <div class="section-title">Machines &amp; Azure Monitor Agent</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="ama-global-search" placeholder="Search machines..."/></div>
          <div class="table-active-filters" id="ama-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="ama-table"><colgroup id="ama-colgroup"></colgroup><thead id="ama-thead"></thead><tbody id="ama-tbody"></tbody></table></div>
        <div class="pager" id="ama-pager"></div>
      </div>

      <div class="section-title">Data Collection Endpoints</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="dce-global-search" placeholder="Search endpoints..."/></div>
          <div class="table-active-filters" id="dce-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="dce-table"><colgroup id="dce-colgroup"></colgroup><thead id="dce-thead"></thead><tbody id="dce-tbody"></tbody></table></div>
        <div class="pager" id="dce-pager"></div>
      </div>
'@
        }
        'obsinventory' {
@'
      <div class="page-header" id="obsinv-header"></div>

      <div class="section-title">Log Analytics Workspaces</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="obsinv-global-search" placeholder="Search workspaces..."/></div>
          <div class="table-active-filters" id="obsinv-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="obsinv-table"><colgroup id="obsinv-colgroup"></colgroup><thead id="obsinv-thead"></thead><tbody id="obsinv-tbody"></tbody></table></div>
        <div class="pager" id="obsinv-pager"></div>
      </div>
'@
        }
        'policy' {
@'
      <div class="page-header" id="policy-header"></div>

      <div class="section-title">Compliance</div>
      <div class="stat-tiles" id="policy-cards"></div>

      <div class="section-title">Breakdown</div>
      <div class="charts-row">
        <div class="card"><h3>Resource Compliance</h3><div id="policy-chart-compliance"></div></div>
        <div class="card"><h3>Assignments by Effect</h3><div id="policy-chart-effect"></div></div>
      </div>

      <div class="section-title">Assignments</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="policy-global-search" placeholder="Search assignments..."/></div>
          <div class="table-active-filters" id="policy-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="policy-table"><colgroup id="policy-colgroup"></colgroup><thead id="policy-thead"></thead><tbody id="policy-tbody"></tbody></table></div>
        <div class="pager" id="policy-pager"></div>
      </div>
'@
        }
        'policyexemptions' {
@'
      <div class="page-header" id="exempt-header"></div>

      <div class="section-title">Exemptions</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="exempt-global-search" placeholder="Search exemptions..."/></div>
          <div class="table-active-filters" id="exempt-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="exempt-table"><colgroup id="exempt-colgroup"></colgroup><thead id="exempt-thead"></thead><tbody id="exempt-tbody"></tbody></table></div>
        <div class="pager" id="exempt-pager"></div>
      </div>
'@
        }
        'policyremediation' {
@'
      <div class="page-header" id="rem-header"></div>

      <div class="section-title">Remediation</div>
      <div class="stat-tiles" id="rem-cards"></div>

      <div class="section-title">Policies to Remediate</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="rem-global-search" placeholder="Search policies..."/></div>
          <div class="table-active-filters" id="rem-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="rem-table"><colgroup id="rem-colgroup"></colgroup><thead id="rem-thead"></thead><tbody id="rem-tbody"></tbody></table></div>
        <div class="pager" id="rem-pager"></div>
      </div>

      <div class="section-title">Recent Remediation Tasks</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="remtask-global-search" placeholder="Search tasks..."/></div>
          <div class="table-active-filters" id="remtask-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="remtask-table"><colgroup id="remtask-colgroup"></colgroup><thead id="remtask-thead"></thead><tbody id="remtask-tbody"></tbody></table></div>
        <div class="pager" id="remtask-pager"></div>
      </div>
'@
        }
        'securityoverview' {
@'
      <div class="page-header" id="def-header"></div>

      <div class="section-title">Security Posture (Defender for Cloud)</div>
      <div class="stat-tiles" id="def-cards"></div>

      <div class="section-title">Defender Plans by Subscription</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="def-global-search" placeholder="Search subscriptions..."/></div>
          <div class="table-active-filters" id="def-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="def-table"><colgroup id="def-colgroup"></colgroup><thead id="def-thead"></thead><tbody id="def-tbody"></tbody></table></div>
        <div class="pager" id="def-pager"></div>
      </div>
'@
        }
        'securityrecommendations' {
@'
      <div class="page-header" id="secrec-header"></div>

      <div class="section-title">Recommendations by Risk Level</div>
      <div class="stat-tiles" id="secrec-cards"></div>

      <div class="section-title">Recommendations</div>
      <div class="card">
        <div class="table-toolbar">
          <div class="table-search"><span class="table-search-icon">&#128269;</span><input type="text" id="secrec-global-search" placeholder="Search recommendations..."/></div>
          <div class="table-active-filters" id="secrec-active-filters"></div>
        </div>
        <div class="table-scroll"><table class="aer-table" id="secrec-table"><colgroup id="secrec-colgroup"></colgroup><thead id="secrec-thead"></thead><tbody id="secrec-tbody"></tbody></table></div>
        <div class="pager" id="secrec-pager"></div>
      </div>
'@
        }
    }
}

function Get-AerPageDocument {
    param([string] $Page, $Meta)

    $info    = $script:AerPages[$Page]
    $sidebar = Get-AerSidebarHtml -Active $Page -Meta $Meta
    $content = Get-AerPageContent -Page $Page
    $favicon = 'data:image/svg+xml;base64,' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script:AerSvgLogo))
    $exportActions = ''
    $exportPanel = ''
    if ($Page -eq 'overview') {
        $exportFiles = $null
        $exportProp = $Meta.PSObject.Properties['ExportFiles']
        if ($exportProp) { $exportFiles = $exportProp.Value }
        $xlsxHref = if ($exportFiles -and $exportFiles.PSObject.Properties['Xlsx']) { $exportFiles.Xlsx } else { $null }
        $pdfHref  = if ($exportFiles -and $exportFiles.PSObject.Properties['Pdf']) { $exportFiles.Pdf } else { $null }
        $xlsxButton = if ($xlsxHref) { "<a class=`"export-btn excel`" href=`"$xlsxHref`" download title=`"Download Excel workbook`"><span class=`"export-btn-icon`">&#128202;</span><span>XLSX</span></a>" } else { '' }
        $pdfButton  = if ($pdfHref)  { "<a class=`"export-btn pdf`" href=`"$pdfHref`" download title=`"Download PDF report`"><span class=`"export-btn-icon`">&#128462;</span><span>PDF</span></a>" } else { '' }
        if ($xlsxButton -or $pdfButton) {
            $exportActions = "<div class=`"topbar-actions`"><span class=`"topbar-action-label`">Export</span>$xlsxButton$pdfButton</div>"
            $exportPanel = @"
      <div class="export-panel">
        <div class="export-panel-copy">
          <div class="export-panel-kicker">Export</div>
          <div class="export-panel-title">Download the report package</div>
          <div class="export-panel-sub">Executive dashboard workbook and printable PDF generated with this run.</div>
        </div>
        <div class="export-panel-actions">
          $xlsxButton
          $pdfButton
        </div>
      </div>
"@
        }
    }

    @"
<!DOCTYPE html>
<html lang="en-US" data-theme="dark">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Azure Estate Report · $($info.Title)</title>
  <link rel="icon" type="image/svg+xml" href="$favicon"/>
  <link rel="stylesheet" href="assets/style.css"/>
</head>
<body data-page="$Page">

$sidebar

<div class="page-wrapper">

  <div class="topbar">
    <div class="topbar-left">
      <div id="topbar-title" class="topbar-title">$($info.Title)</div>
    </div>
    <div class="topbar-right">
      $exportActions
      <span class="topbar-meta">Generated <strong>$($Meta.GeneratedAt)</strong></span>
    </div>
  </div>

  <div class="page-content">
    <div class="page active">
$exportPanel
$content
    </div>
  </div>

  <footer class="footer">
    <span>Generated by <strong>AER</strong> v$($Meta.ModuleVersion) &#183; Read-only &#183; No changes made to your environment</span>
    <span>$($Meta.Account) &#183; $($Meta.TenantDomain)</span>
  </footer>

</div>

<script src="assets/data.js"></script>
<script src="assets/app.js"></script>
</body>
</html>
"@
}

function New-AerReportSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $ReportData,
        [Parameter(Mandatory)] [string] $OutputPath
    )

    $meta      = $ReportData.metadata
    $assetsDir = Join-Path $OutputPath 'assets'
    $null = New-Item -ItemType Directory -Force -Path $OutputPath
    $null = New-Item -ItemType Directory -Force -Path $assetsDir

    # Offline executive exports (download buttons on the Overview page).
    $null = New-AerReportExports -ReportData $ReportData -OutputPath $OutputPath
    $meta = $ReportData.metadata

    # Shared assets
    Get-AerStyleCss | Out-File -FilePath (Join-Path $assetsDir 'style.css') -Encoding utf8 -Force
    Get-AerAppJs    | Out-File -FilePath (Join-Path $assetsDir 'app.js')    -Encoding utf8 -Force
    $dataJson = $ReportData | ConvertTo-Json -Depth 20 -Compress
    "window.AerData = $dataJson;" | Out-File -FilePath (Join-Path $assetsDir 'data.js') -Encoding utf8 -Force

    # One HTML file per menu item
    foreach ($page in $script:AerPages.Keys) {
        $doc  = Get-AerPageDocument -Page $page -Meta $meta
        $file = Join-Path $OutputPath $script:AerPages[$page].File
        $doc | Out-File -FilePath $file -Encoding utf8 -Force
    }

    return (Join-Path $OutputPath 'index.html')
}
