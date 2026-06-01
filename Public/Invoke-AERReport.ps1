function Invoke-AerReport {
<#
.SYNOPSIS
    Generates a rich, fully-offline HTML "Azure Estate Report" (AER) for one or more Azure subscriptions.

.DESCRIPTION
    Invoke-AerReport connects to Azure using your current Az context (from Connect-AzAccount),
    discovers the subscriptions you can access, and collects a READ-ONLY inventory of your Azure
    estate through Azure Resource Graph and ARM REST APIs. It then renders a multi-page,
    self-contained HTML dashboard that you can open straight from disk (no web server and no
    internet connection required to view it).

    The report spans: resource inventory, cloud structure (management groups & subscriptions),
    Azure Advisor, Compute (VMs & scale sets), Databases, Applications, Network (VNets, peerings,
    load balancers), Observability (diagnostic settings coverage, AMA/DCRs, Log Analytics
    inventory), Azure Policy (compliance, assignments, exemptions, remediation) and Microsoft
    Defender for Cloud posture, plus Findings (cost waste and observability recommendations).

    The command is strictly READ-ONLY: it never creates, modifies, or deletes any Azure resource.
    Collection runs in parallel across many independent collectors for speed.

    Requirements: PowerShell 7+, the Az.Accounts and Az.ResourceGraph modules, and an
    authenticated Azure session (Connect-AzAccount). Minimum RBAC is Reader on the target
    scope; add Monitoring Reader for richer observability data.

.PARAMETER OutputPath
    Folder where the HTML report is written (created if it does not exist). Defaults to
    '.\aer-report'. The report entry point is <OutputPath>\index.html.

.PARAMETER SubscriptionId
    One or more subscription IDs (GUIDs) to include. When omitted, every subscription available
    in the current Az context is scanned.

.PARAMETER ExcludeSubscriptionName
    One or more subscription display names to exclude from the scan. Matching is exact and
    case-insensitive (wildcards are not supported).

.PARAMETER MaxParallelCollectors
    Number of data collectors to run concurrently (1-10). Higher values finish faster but issue
    more API calls in parallel. Defaults to 4.

.PARAMETER SampleData
    Generate the report with a rich built-in sample dataset instead of connecting to Azure.
    This is useful for validating the HTML layout, navigation and tables without requiring
    Azure authentication or tenant access.

.PARAMETER OpenReport
    Open the generated index.html in your default browser as soon as the report is ready.

.PARAMETER PassThru
    Emit a summary object (output paths, headline metrics and duration) to the pipeline instead
    of returning nothing.

.EXAMPLE
    Invoke-AerReport

    Scans every subscription in the current Az context and writes the report to .\aer-report.

.EXAMPLE
    Invoke-AerReport -OutputPath 'C:\Reports\Contoso' -OpenReport

    Writes the report to a custom folder and opens it in the browser when finished.

.EXAMPLE
    Invoke-AerReport -SubscriptionId '00000000-0000-0000-0000-000000000000'

    Scans only the specified subscription.

.EXAMPLE
    Invoke-AerReport -ExcludeSubscriptionName 'Sandbox','Visual Studio Enterprise' -MaxParallelCollectors 8

    Scans every subscription except the two named ones, using 8 parallel collectors.

.EXAMPLE
    Invoke-AerReport -SampleData -OutputPath .\aer-sample -OpenReport

    Generates the offline report using built-in fake data so you can validate the layout.

.EXAMPLE
    $r = Invoke-AerReport -PassThru
    $r.Resources
    $r.IndexHtml

    Captures the summary object so you can inspect headline metrics and the report path.

.INPUTS
    None. Invoke-AerReport does not accept pipeline input.

.OUTPUTS
    None by default. With -PassThru, a [pscustomobject] summary containing the output paths,
    headline counts and the run duration.

.NOTES
    READ-ONLY — no changes are ever made to your Azure environment.
    Requires PowerShell 7+, Az.Accounts and Az.ResourceGraph, and an authenticated Az session
    (Connect-AzAccount). Author: AER contributors. License: MIT.

.LINK
    https://github.com/TrimTechBr/azure-state-report
#>
    [CmdletBinding()]
    param(
        [string]   $OutputPath = '.\aer-report',
        [string[]] $SubscriptionId,
        [string[]] $ExcludeSubscriptionName = @(),
        [ValidateRange(1, 10)]
        [int]      $MaxParallelCollectors = 4,
        [switch]   $SampleData,
        [switch]   $OpenReport,
        [switch]   $PassThru
    )

    $startedAt = Get-Date
    $version   = try { (Get-Module Aer).Version.ToString() } catch { '' }
    if ([string]::IsNullOrWhiteSpace($version)) { $version = '0.1.0' }

    # ── Friendly console output helpers (icons + colour) ─────────────────────
    function Write-AerMsg([string]$Icon, [System.ConsoleColor]$Color, [string]$Msg, [string]$Detail) {
        Write-Host "  $Icon " -ForegroundColor $Color -NoNewline
        if ($Detail) { Write-Host $Msg -NoNewline; Write-Host "  $Detail" -ForegroundColor DarkGray }
        else { Write-Host $Msg }
    }
    function Format-AerNum($n) { '{0:N0}' -f [int64]([math]::Round([double]($n ?? 0))) }
    function Format-AerDuration([double]$Milliseconds) {
        $ts = [timespan]::FromMilliseconds([math]::Round($Milliseconds))
        if ($ts.TotalMinutes -ge 1) { return '{0}m {1}s' -f [int][math]::Floor($ts.TotalMinutes), $ts.Seconds }
        return '{0:N1}s' -f $ts.TotalSeconds
    }
    function Limit-AerConsoleText($Value, [int]$Width) {
        $text = "$($Value ?? '')" -replace '\s+', ' '
        $text = $text.Trim()
        if ($text.Length -le $Width) { return $text.PadRight($Width) }
        if ($Width -le 3) { return $text.Substring(0, $Width) }
        return ($text.Substring(0, $Width - 1) + '…')
    }
    function Get-AerConsoleCell($Row, [string]$Key) {
        if ($null -eq $Row) { return '' }
        $prop = $Row.PSObject.Properties[$Key]
        if ($prop) { return $prop.Value }
        return ''
    }
    function Write-AerConsoleTable([string]$Title, [object[]]$Rows, [object[]]$Columns, [string]$Icon = '▦') {
        $rowsSafe = @($Rows)
        $widths = @()
        foreach ($col in $Columns) {
            $maxWidth = if ($col.PSObject.Properties['Width']) { [int]$col.Width } else { 42 }
            $w = [math]::Min($maxWidth, [math]::Max(4, "$($col.Label)".Length))
            foreach ($row in $rowsSafe) {
                $cellLen = "$(Get-AerConsoleCell $row $col.Key)".Length
                if ($cellLen -gt $w) { $w = [math]::Min($maxWidth, $cellLen) }
            }
            $widths += $w
        }

        $top = '  ┌' + (($widths | ForEach-Object { '─' * ($_ + 2) }) -join '┬') + '┐'
        $mid = '  ├' + (($widths | ForEach-Object { '─' * ($_ + 2) }) -join '┼') + '┤'
        $bot = '  └' + (($widths | ForEach-Object { '─' * ($_ + 2) }) -join '┴') + '┘'

        Write-Host ''
        Write-Host "  $Icon $Title" -ForegroundColor White
        Write-Host $top -ForegroundColor DarkGray
        $headerCells = for ($i = 0; $i -lt $Columns.Count; $i++) { Limit-AerConsoleText $Columns[$i].Label $widths[$i] }
        Write-Host ('  │ ' + ($headerCells -join ' │ ') + ' │') -ForegroundColor Cyan
        Write-Host $mid -ForegroundColor DarkGray
        foreach ($row in $rowsSafe) {
            $cells = for ($i = 0; $i -lt $Columns.Count; $i++) {
                $value = Get-AerConsoleCell $row $Columns[$i].Key
                $text = Limit-AerConsoleText $value $widths[$i]
                if ($Columns[$i].PSObject.Properties['Align'] -and $Columns[$i].Align -eq 'Right') {
                    $text.Trim().PadLeft($widths[$i])
                } else {
                    $text
                }
            }
            Write-Host ('  │ ' + ($cells -join ' │ ') + ' │') -ForegroundColor Gray
        }
        Write-Host $bot -ForegroundColor DarkGray
    }
    function Get-AerExportStats($ExportFiles) {
        $errors = @()
        $success = 0
        if ($ExportFiles) {
            if ($ExportFiles.PSObject.Properties['Errors']) {
                $errors = @($ExportFiles.Errors | Where-Object { $null -ne $_ })
            }
            if ($ExportFiles.PSObject.Properties['Xlsx'] -and $ExportFiles.Xlsx) { $success++ }
            if ($ExportFiles.PSObject.Properties['Pdf'] -and $ExportFiles.Pdf) { $success++ }
        }
        [pscustomobject]@{ Success = $success; Errors = $errors.Count; Total = 2; ErrorsList = $errors }
    }
    function Write-AerExportStatus($ExportFiles, [string]$OutputPath) {
        if (-not $ExportFiles) { return }
        if ($ExportFiles.Xlsx) {
            $xlsxPath = Join-Path $OutputPath ($ExportFiles.Xlsx -replace '/', [IO.Path]::DirectorySeparatorChar)
            Write-AerMsg '⇩' Cyan 'Excel export ready' (Resolve-Path $xlsxPath).Path
        }
        if ($ExportFiles.Pdf) {
            $pdfPath = Join-Path $OutputPath ($ExportFiles.Pdf -replace '/', [IO.Path]::DirectorySeparatorChar)
            Write-AerMsg '⇩' Cyan 'PDF export ready' (Resolve-Path $pdfPath).Path
        }
    }
    function Write-AerRunSummary {
        param(
            $Summary,
            [string] $Duration,
            [int] $CollectorSuccess,
            [int] $CollectorErrors,
            [int] $CollectorTotal,
            [string] $CollectorLabel = 'Collectors',
            $CollectionErrors = @(),
            $ExportFiles = $null
        )

        $signals = @{
            'Subscriptions' = 'Scope'; 'Resource groups' = 'Estate'; 'Resources' = 'Estate'
            'Virtual machines' = 'Compute'; 'Databases' = 'Data'; 'Advisor recommendations' = 'Optimization'
            'Policy assignments' = 'Governance'; 'Defender unhealthy' = 'Security'; 'Cost findings' = 'Savings'
            'General findings' = 'Risk'
        }
        $metricRows = foreach ($k in $Summary.Keys) {
            [pscustomobject]@{
                Metric = $k
                Count  = Format-AerNum $Summary[$k]
                Signal = $signals[$k] ?? 'Overview'
            }
        }
        Write-AerConsoleTable 'Executive summary' $metricRows @(
            [pscustomobject]@{ Key = 'Metric'; Label = 'Metric'; Width = 30 },
            [pscustomobject]@{ Key = 'Count';  Label = 'Count';  Width = 14; Align = 'Right' },
            [pscustomobject]@{ Key = 'Signal'; Label = 'Signal'; Width = 18 }
        ) '◈'

        $exportStats = Get-AerExportStats $ExportFiles
        $healthRows = @(
            [pscustomobject]@{
                Area = $CollectorLabel; Success = Format-AerNum $CollectorSuccess; Errors = Format-AerNum $CollectorErrors; Total = Format-AerNum $CollectorTotal
                Status = if ($CollectorErrors -eq 0) { '✓ Healthy' } else { '⚠ Partial' }
            },
            [pscustomobject]@{
                Area = 'Exports'; Success = Format-AerNum $exportStats.Success; Errors = Format-AerNum $exportStats.Errors; Total = Format-AerNum $exportStats.Total
                Status = if ($exportStats.Errors -eq 0) { '✓ Ready' } else { '⚠ Review' }
            },
            [pscustomobject]@{
                Area = 'Duration'; Success = ''; Errors = ''; Total = ''; Status = "⏱ $Duration"
            }
        )
        Write-AerConsoleTable 'Run health' $healthRows @(
            [pscustomobject]@{ Key = 'Area';    Label = 'Area';    Width = 18 },
            [pscustomobject]@{ Key = 'Success'; Label = 'Success'; Width = 12; Align = 'Right' },
            [pscustomobject]@{ Key = 'Errors';  Label = 'Errors';  Width = 10; Align = 'Right' },
            [pscustomobject]@{ Key = 'Total';   Label = 'Total';   Width = 10; Align = 'Right' },
            [pscustomobject]@{ Key = 'Status';  Label = 'Status';  Width = 18 }
        ) '☑'

        $errorRows = [System.Collections.Generic.List[object]]::new()
        $i = 1
        foreach ($e in @($CollectionErrors)) {
            $errorRows.Add([pscustomobject]@{ '# ' = $i; Type = 'Collector'; Name = "$($e.Collector)"; Message = "$($e.Message)" })
            $i++
        }
        foreach ($e in @($exportStats.ErrorsList)) {
            $errorRows.Add([pscustomobject]@{ '# ' = $i; Type = 'Export'; Name = "$($e.Export)"; Message = "$($e.Message)" })
            $i++
        }
        if ($errorRows.Count -eq 0) {
            $errorRows.Add([pscustomobject]@{ '# ' = '—'; Type = 'None'; Name = 'All clear'; Message = 'No collection or export errors detected.' })
        }
        Write-AerConsoleTable 'Error details' @($errorRows) @(
            [pscustomobject]@{ Key = '# ';      Label = '#';       Width = 4; Align = 'Right' },
            [pscustomobject]@{ Key = 'Type';    Label = 'Type';    Width = 12 },
            [pscustomobject]@{ Key = 'Name';    Label = 'Name';    Width = 22 },
            [pscustomobject]@{ Key = 'Message'; Label = 'Message'; Width = 72 }
        ) '🛡'
    }

    Write-Host ''
    Write-Host '  AER ' -ForegroundColor Cyan -NoNewline
    Write-Host '· Azure Estate Report ' -ForegroundColor White -NoNewline
    Write-Host "v$version" -ForegroundColor DarkGray
    Write-Host '  ──────────────────────────────────────────────' -ForegroundColor DarkGray

    if ($SampleData) {
        Write-AerMsg '▶' Cyan 'Generating sample dataset…' 'Azure connection skipped'
        $reportData = New-AerSampleReportData -ModuleVersion $version -GeneratedAt $startedAt
        Write-AerMsg '✓' Green 'Sample dataset ready' "$($reportData.inventory.TotalResources) resources"

        Write-AerMsg '▶' Cyan 'Rendering HTML report…'
        $indexPath = New-AerReportSite -ReportData $reportData -OutputPath $OutputPath
        $fullIndex = (Resolve-Path $indexPath).Path
        Write-AerMsg '✓' Green 'Report generated' $fullIndex
        Write-AerExportStatus -ExportFiles $reportData.metadata.ExportFiles -OutputPath $OutputPath

        $totalMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds)
        $durationStr = Format-AerDuration $totalMs

        $summary = [ordered]@{
            'Subscriptions'           = ($reportData.inventory.Subscriptions ?? 0)
            'Resource groups'         = ($reportData.inventory.TotalResourceGroups ?? 0)
            'Resources'               = ($reportData.inventory.TotalResources ?? 0)
            'Virtual machines'        = ($reportData.virtualMachines.TotalVMs ?? 0)
            'Databases'               = ($reportData.databases.TotalServices ?? 0)
            'Advisor recommendations' = ($reportData.advisor.TotalRecommendations ?? 0)
            'Policy assignments'      = ($reportData.policy.Assignments.Total ?? 0)
            'Defender unhealthy'      = ($reportData.defender.Summary.Unhealthy ?? 0)
            'Cost findings'           = ($reportData.cost.TotalWastedResources ?? 0)
            'General findings'        = ($reportData.security.TotalGaps ?? 0)
        }
        Write-AerRunSummary `
            -Summary $summary `
            -Duration $durationStr `
            -CollectorSuccess 1 `
            -CollectorErrors 0 `
            -CollectorTotal 1 `
            -CollectorLabel 'Sample dataset' `
            -CollectionErrors @() `
            -ExportFiles $reportData.metadata.ExportFiles
        Write-Host ''
        Write-AerMsg '✓' Green 'Done.' "open $fullIndex"
        Write-Host ''

        if ($OpenReport) {
            try { Invoke-Item $indexPath } catch { Write-AerMsg '⚠' Yellow 'Could not open the report automatically' $_.Exception.Message }
        }

        if ($PassThru) {
            return [pscustomobject]@{
                OutputPath             = (Resolve-Path $OutputPath).Path
                IndexHtml              = $fullIndex
                ManagementGroups       = $reportData.inventory.ManagementGroups ?? 0
                Subscriptions          = $reportData.inventory.Subscriptions ?? 0
                ResourceGroups         = $reportData.inventory.TotalResourceGroups ?? 0
                Resources              = $reportData.inventory.TotalResources ?? 0
                SecurityGaps           = $reportData.security.TotalGaps ?? 0
                WastedResources        = $reportData.cost.TotalWastedResources ?? 0
                AdvisorRecommendations = $reportData.advisor.TotalRecommendations ?? 0
                VirtualMachines        = $reportData.virtualMachines.TotalVMs ?? 0
                VmScaleSets            = $reportData.virtualMachineScaleSets.TotalVMSS ?? 0
                CollectionErrors       = 0
                Duration               = [timespan]::FromMilliseconds($totalMs)
                ExcelWorkbook          = if ($reportData.metadata.ExportFiles.Xlsx) { (Resolve-Path (Join-Path $OutputPath ($reportData.metadata.ExportFiles.Xlsx -replace '/', [IO.Path]::DirectorySeparatorChar))).Path } else { $null }
                PdfReport              = if ($reportData.metadata.ExportFiles.Pdf) { (Resolve-Path (Join-Path $OutputPath ($reportData.metadata.ExportFiles.Pdf -replace '/', [IO.Path]::DirectorySeparatorChar))).Path } else { $null }
                ExportErrors           = @($reportData.metadata.ExportFiles.Errors)
                SampleData             = $true
            }
        }

        return
    }

    # ── Phase 1 — Azure context ──────────────────────────────────────────────
    Write-AerMsg '▶' Cyan 'Resolving Azure context…'
    $ctx = Resolve-AerContext `
        -SubscriptionId          $SubscriptionId `
        -ExcludeSubscriptionName $ExcludeSubscriptionName
    Write-AerMsg '✓' Green "Signed in as $($ctx.Account)" "tenant: $($ctx.TenantDomain)"
    Write-AerMsg '✓' Green "$($ctx.Subscriptions.Count) subscription(s) in scope"

    $collectionErrors = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    $subIds    = $ctx.SubscriptionIds
    $subMap    = $ctx.SubscriptionMap
    $modDir    = if ($m = Get-Module Aer -ErrorAction SilentlyContinue) {
        $m.ModuleBase
    } else {
        (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    }
    # Pass the parent's module search paths so workers can find Az.ResourceGraph
    $psModPath = $env:PSModulePath

    $collectors = @('inventory', 'security', 'cost', 'advisor', 'structure', 'vm', 'vmss', 'database', 'relational', 'dataservices', 'application', 'appservices', 'network', 'vnets', 'loadbalancers', 'observability', 'diagnosticsettings', 'datacollection', 'obsinventory', 'policy', 'defender')

    # ── Phase 2 — Parallel data collection ───────────────────────────────────
    Write-AerMsg '▶' Cyan 'Collecting estate data…' "$($collectors.Count) collectors · parallelism $MaxParallelCollectors"
    $results    = $collectors | ForEach-Object -Parallel {
        $name       = $_
        $subIds     = $using:subIds
        $subMap     = $using:subMap
        $errBag     = $using:collectionErrors
        $dir        = $using:modDir
        $modulePath = $using:psModPath

        # Restore parent module paths and import Az.ResourceGraph so that
        # Search-AzGraph and Invoke-AzRestMethod are available with the saved Az context.
        $env:PSModulePath = $modulePath
        Import-Module Az.ResourceGraph -ErrorAction Stop

        . (Join-Path $dir 'Core\ResourceGraph.ps1')
        $collectorFile = switch ($name) {
            'inventory' { 'Collectors\Inventory.ps1' }
            'security'  { 'Collectors\Security.ps1'  }
            'cost'      { 'Collectors\Cost.ps1'       }
            'advisor'   { 'Collectors\Advisor.ps1'    }
            'structure' { 'Collectors\CloudStructure.ps1' }
            'vm'        { 'Collectors\VirtualMachines.ps1' }
            'vmss'      { 'Collectors\VmScaleSets.ps1' }
            'database'  { 'Collectors\Databases.ps1' }
            'relational'{ 'Collectors\RelationalDatabases.ps1' }
            'dataservices' { 'Collectors\DataServices.ps1' }
            'application' { 'Collectors\Applications.ps1' }
            'appservices' { 'Collectors\ApplicationServices.ps1' }
            'network'     { 'Collectors\Network.ps1' }
            'vnets'       { 'Collectors\Vnets.ps1' }
            'loadbalancers' { 'Collectors\LoadBalancers.ps1' }
            'observability' { 'Collectors\Observability.ps1' }
            'diagnosticsettings' { 'Collectors\DiagnosticSettings.ps1' }
            'datacollection' { 'Collectors\DataCollection.ps1' }
            'obsinventory' { 'Collectors\ObsInventory.ps1' }
            'policy'      { 'Collectors\Policy.ps1' }
            'defender'    { 'Collectors\Defender.ps1' }
        }
        . (Join-Path $dir $collectorFile)

        try {
            $data = switch ($name) {
                'inventory' { Get-AerInventory       -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'security'  { Get-AerSecurityGaps    -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'cost'      { Get-AerCostWaste        -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'advisor'   { Get-AerAdvisorSummary   -SubscriptionIds $subIds }
                'structure' { Get-AerCloudStructure   -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'vm'        { Get-AerVirtualMachines   -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'vmss'      { Get-AerVmScaleSets       -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'database'  { Get-AerDatabases         -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'relational'{ Get-AerRelationalDatabases -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'dataservices' { Get-AerDataServices    -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'application' { Get-AerApplications      -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'appservices' { Get-AerApplicationServices -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'network'     { Get-AerNetwork           -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'vnets'       { Get-AerVnets             -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'loadbalancers' { Get-AerLoadBalancers   -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'observability' { Get-AerObservability    -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'diagnosticsettings' { Get-AerDiagnosticSettings -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'datacollection' { Get-AerDataCollection   -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'obsinventory' { Get-AerObsInventory       -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'policy'      { Get-AerPolicy            -SubscriptionIds $subIds -SubscriptionMap $subMap }
                'defender'    { Get-AerDefender          -SubscriptionIds $subIds -SubscriptionMap $subMap }
            }
            [pscustomobject]@{ Name = $name; Data = $data; Error = $null }
        }
        catch {
            $errBag.Add([pscustomobject]@{
                Collector  = $name
                Message    = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            })
            [pscustomobject]@{ Name = $name; Data = $null; Error = $_.Exception.Message }
        }
    } -ThrottleLimit $MaxParallelCollectors

    # Per-collector status (success roll-up + any failures, full traces under -Verbose)
    $okCount = @($results | Where-Object { -not $_.Error }).Count
    if ($okCount -eq $collectors.Count) { Write-AerMsg '✓' Green "Collected all $okCount data sets" }
    else { Write-AerMsg '⚠' Yellow "Collected $okCount of $($collectors.Count) data sets" }
    foreach ($r in ($results | Where-Object { $_.Error } | Sort-Object Name)) {
        Write-AerMsg '✗' Red "$($r.Name) collector failed" $r.Error
    }
    foreach ($e in $collectionErrors) { Write-Verbose "[$($e.Collector)] $($e.StackTrace)" }

    $resultMap = @{}
    foreach ($r in $results) { $resultMap[$r.Name] = $r.Data }

    # Assemble report data
    $durationMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds)
    $reportData = [pscustomobject]@{
        metadata = [pscustomobject]@{
            GeneratedAt   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'
            TenantDomain  = $ctx.TenantDomain
            Account       = $ctx.Account
            DurationMs    = $durationMs
            ModuleVersion = $version
        }
        inventory        = $resultMap['inventory']
        security         = $resultMap['security']
        cost             = $resultMap['cost']
        advisor          = $resultMap['advisor']
        structure        = $resultMap['structure']
        virtualMachines  = $resultMap['vm']
        virtualMachineScaleSets = $resultMap['vmss']
        databases        = $resultMap['database']
        relationalDatabases = $resultMap['relational']
        dataServices     = $resultMap['dataservices']
        applications     = $resultMap['application']
        applicationServices = $resultMap['appservices']
        network          = $resultMap['network']
        vnets            = $resultMap['vnets']
        loadBalancers    = $resultMap['loadbalancers']
        observability    = $resultMap['observability']
        diagnosticSettings = $resultMap['diagnosticsettings']
        dataCollection   = $resultMap['datacollection']
        obsInventory     = $resultMap['obsinventory']
        policy           = $resultMap['policy']
        defender         = $resultMap['defender']
        collectionErrors = @($collectionErrors)
    }

    # ── Phase 3 — Render the HTML site ───────────────────────────────────────
    Write-AerMsg '▶' Cyan 'Rendering HTML report…'
    $indexPath = New-AerReportSite -ReportData $reportData -OutputPath $OutputPath
    $fullIndex = (Resolve-Path $indexPath).Path
    Write-AerMsg '✓' Green 'Report generated' $fullIndex
    Write-AerExportStatus -ExportFiles $reportData.metadata.ExportFiles -OutputPath $OutputPath

    # ── Summary table ────────────────────────────────────────────────────────
    $totalMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds)
    $durationStr = Format-AerDuration $totalMs

    $summary = [ordered]@{
        'Subscriptions'           = $ctx.Subscriptions.Count
        'Resource groups'         = ($resultMap['inventory']?.TotalResourceGroups ?? 0)
        'Resources'               = ($resultMap['inventory']?.TotalResources ?? 0)
        'Virtual machines'        = ($resultMap['vm']?.TotalVMs ?? 0)
        'Databases'               = ($resultMap['database']?.TotalServices ?? 0)
        'Advisor recommendations' = ($resultMap['advisor']?.TotalRecommendations ?? 0)
        'Policy assignments'      = ($resultMap['policy']?.Assignments.Total ?? 0)
        'Defender unhealthy'      = ($resultMap['defender']?.Summary.Unhealthy ?? 0)
        'Cost findings'           = ($resultMap['cost']?.TotalWastedResources ?? 0)
        'General findings'        = ($resultMap['security']?.TotalGaps ?? 0)
    }
    Write-AerRunSummary `
        -Summary $summary `
        -Duration $durationStr `
        -CollectorSuccess $okCount `
        -CollectorErrors $collectionErrors.Count `
        -CollectorTotal $collectors.Count `
        -CollectionErrors @($collectionErrors) `
        -ExportFiles $reportData.metadata.ExportFiles
    Write-Host ''
    Write-AerMsg '✓' Green 'Done.' "open $fullIndex"
    Write-Host ''

    if ($OpenReport) {
        try { Invoke-Item $indexPath } catch { Write-AerMsg '⚠' Yellow 'Could not open the report automatically' $_.Exception.Message }
    }

    if ($PassThru) {
        return [pscustomobject]@{
            OutputPath             = (Resolve-Path $OutputPath).Path
            IndexHtml              = $fullIndex
            ManagementGroups       = $resultMap['inventory']?.ManagementGroups ?? 0
            Subscriptions          = $resultMap['inventory']?.Subscriptions ?? 0
            ResourceGroups         = $resultMap['inventory']?.TotalResourceGroups ?? 0
            Resources              = $resultMap['inventory']?.TotalResources ?? 0
            SecurityGaps           = $resultMap['security']?.TotalGaps ?? 0
            WastedResources        = $resultMap['cost']?.TotalWastedResources ?? 0
            AdvisorRecommendations = $resultMap['advisor']?.TotalRecommendations ?? 0
            VirtualMachines        = $resultMap['vm']?.TotalVMs ?? 0
            VmScaleSets            = $resultMap['vmss']?.TotalVMSS ?? 0
            CollectionErrors       = $collectionErrors.Count
            Duration               = [timespan]::FromMilliseconds($totalMs)
            ExcelWorkbook          = if ($reportData.metadata.ExportFiles.Xlsx) { (Resolve-Path (Join-Path $OutputPath ($reportData.metadata.ExportFiles.Xlsx -replace '/', [IO.Path]::DirectorySeparatorChar))).Path } else { $null }
            PdfReport              = if ($reportData.metadata.ExportFiles.Pdf) { (Resolve-Path (Join-Path $OutputPath ($reportData.metadata.ExportFiles.Pdf -replace '/', [IO.Path]::DirectorySeparatorChar))).Path } else { $null }
            ExportErrors           = @($reportData.metadata.ExportFiles.Errors)
        }
    }
}
