function Get-AerObservability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        [Parameter(Mandatory)]            $SubscriptionMap
    )

    $subLookup = @{}
    if ($SubscriptionMap -is [hashtable]) {
        $subLookup = $SubscriptionMap
    } elseif ($SubscriptionMap) {
        $SubscriptionMap.PSObject.Properties | ForEach-Object { $subLookup[$_.Name] = $_.Value }
    }
    function SubName($id) {
        if (-not $id) { return 'Unknown' }
        $n = $subLookup[$id.ToLowerInvariant()]
        if ($n) { $n } else { $id }
    }
    function Pctg($part, $total) { if ($total -gt 0) { [int][math]::Round($part / $total * 100) } else { $null } }

    # Expand-AerRows + Invoke-AerArmBatch come from Core\ResourceGraph.ps1.
    function ArgRows($query) { Expand-AerRows (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $query) }

    # ── Inventory counts by type (cheap) ─────────────────────────────────────
    $cnt = @{}
    try {
        $types = "'microsoft.operationalinsights/workspaces','microsoft.insights/components','microsoft.insights/datacollectionrules','microsoft.insights/datacollectionendpoints','microsoft.insights/actiongroups','microsoft.insights/metricalerts','microsoft.insights/scheduledqueryrules','microsoft.insights/activitylogalerts','microsoft.insights/workbooks','microsoft.portal/dashboards','microsoft.dashboard/grafana','microsoft.automation/automationaccounts'"
        foreach ($r in (ArgRows "resources | where type in~ ($types) | summarize c = count() by t = tolower(type)")) {
            if ($r.t) { $cnt[$r.t] = [int]$r.c }
        }
    } catch { Write-Warning "[Observability.counts] $($_.Exception.Message)" }
    function C($t) { [int]($cnt[$t] ?? 0) }
    $totalObs = 0; foreach ($v in $cnt.Values) { $totalObs += [int]$v }

    # Diagnostic Settings coverage now lives in its own collector
    # (Get-AerDiagnosticSettings); the Overview reads it from d.diagnosticSettings.

    # ── AMA (Azure Monitor Agent) coverage on VM + Arc machines ──────────────
    $machines = 0; $withAma = 0
    try {
        $machines = (@(ArgRows "resources | where type in~ ('microsoft.compute/virtualmachines','microsoft.hybridcompute/machines') | project id = tolower(id)")).Count
        $amaParents = @{}
        foreach ($e in (ArgRows "resources | where type in~ ('microsoft.compute/virtualmachines/extensions','microsoft.hybridcompute/machines/extensions') | where name has 'AzureMonitorWindowsAgent' or name has 'AzureMonitorLinuxAgent' or tostring(properties.type) in~ ('AzureMonitorWindowsAgent','AzureMonitorLinuxAgent') | project id = tolower(id)")) {
            if ($e.id) {
                $parent = ($e.id -split '/extensions/')[0]
                if ($parent) { $amaParents[$parent] = $true }
            }
        }
        $withAma = $amaParents.Count
    } catch { Write-Warning "[Observability.ama] $($_.Exception.Message)" }

    # ── Application Insights coverage on Web / Function apps ─────────────────
    # An app is "covered" if it references App Insights either via the portal
    # 'hidden-link:<appId>' tag on the component (legacy) OR via an
    # APPINSIGHTS_INSTRUMENTATIONKEY / APPLICATIONINSIGHTS_CONNECTION_STRING app
    # setting (the modern, far more common path — read via ARM batch).
    $apps = 0; $appsCovered = 0
    try {
        $appIds  = @{}                                              # id -> covered
        $appList = [System.Collections.Generic.List[string]]::new()
        foreach ($a in (ArgRows "resources | where type =~ 'microsoft.web/sites' | project id = tolower(id)")) {
            if ($a.id -and -not $appIds.ContainsKey($a.id)) { $appIds[$a.id] = $false; $appList.Add($a.id) }
        }
        $apps = $appIds.Count

        # Signal 1 — hidden-link tags on App Insights components (cheap, ARG)
        $viaTag = 0
        foreach ($c in (ArgRows "resources | where type =~ 'microsoft.insights/components' | where isnotempty(tags) | project tags")) {
            if (-not $c.tags) { continue }
            foreach ($p in $c.tags.PSObject.Properties) {
                if ($p.Name -like 'hidden-link:*' -and $p.Name -like '*/sites/*') {
                    $linked = ($p.Name -replace '^hidden-link:', '').ToLowerInvariant()
                    if ($appIds.ContainsKey($linked) -and -not $appIds[$linked]) { $appIds[$linked] = $true; $viaTag++ }
                }
            }
        }

        # Signal 2 — App Insights app settings (authoritative, ARM batch POST).
        # Requires the 'Microsoft.Web/sites/config/list/Action' permission;
        # plain Reader/Monitoring Reader gets HTTP 403 here (→ undetectable).
        $aiKeys = @('APPINSIGHTS_INSTRUMENTATIONKEY','APPLICATIONINSIGHTS_CONNECTION_STRING','APPLICATIONINSIGHTS_CONNECTIONSTRING','APPLICATIONINSIGHTSAGENT_EXTENSION_VERSION','APPLICATIONINSIGHTS_CONNECTION_STRING__AccountEndpoint')
        $viaSettings = 0; $s2xx = 0; $s403 = 0; $sOther = 0
        if ($appList.Count) {
            $reqs = [System.Collections.Generic.List[object]]::new()
            $idByName = @{}
            for ($i = 0; $i -lt $appList.Count; $i++) {
                $idByName[$i.ToString()] = $appList[$i]
                $reqs.Add([ordered]@{
                    httpMethod = 'POST'
                    name       = $i.ToString()
                    url        = "$($appList[$i])/config/appsettings/list?api-version=2022-03-01"
                })
            }
            $responses = Invoke-AerArmBatch $reqs
            foreach ($key in $responses.Keys) {
                $rr = $responses[$key]
                if ($rr.httpStatusCode -ge 200 -and $rr.httpStatusCode -lt 300 -and $rr.content -and $rr.content.properties) {
                    $s2xx++
                    foreach ($pp in $rr.content.properties.PSObject.Properties) {
                        if (($aiKeys -contains $pp.Name) -and "$($pp.Value)".Trim()) {
                            if (-not $appIds[$idByName[$key]]) { $appIds[$idByName[$key]] = $true; $viaSettings++ }
                            break
                        }
                    }
                }
                elseif ($rr.httpStatusCode -eq 403) { $s403++ }
                else { $sOther++ }
            }
        }

        $appsCovered = (@($appIds.Values | Where-Object { $_ })).Count
        Write-Verbose "[Observability.appInsights] apps=$apps covered=$appsCovered viaTag=$viaTag viaSettings=$viaSettings | appsettings: 2xx=$s2xx 403(no-permission)=$s403 other=$sOther"
    } catch { Write-Warning "[Observability.appInsights] $($_.Exception.Message)" }

    return [pscustomobject]@{
        Total                  = $totalObs
        SubscriptionsEvaluated = @($SubscriptionIds).Count
        Workspaces             = C 'microsoft.operationalinsights/workspaces'
        AmaCoverage = [pscustomobject]@{
            Machines = $machines
            WithAma  = $withAma
            Percent  = (Pctg $withAma $machines)
        }
        AppInsightsCoverage = [pscustomobject]@{
            Apps    = $apps
            Covered = $appsCovered
            Percent = (Pctg $appsCovered $apps)
        }
        Counts = [pscustomobject]@{
            Workspaces              = C 'microsoft.operationalinsights/workspaces'
            AppInsights             = C 'microsoft.insights/components'
            DataCollectionRules     = C 'microsoft.insights/datacollectionrules'
            DataCollectionEndpoints = C 'microsoft.insights/datacollectionendpoints'
            ActionGroups            = C 'microsoft.insights/actiongroups'
            AlertRules              = (C 'microsoft.insights/metricalerts') + (C 'microsoft.insights/scheduledqueryrules') + (C 'microsoft.insights/activitylogalerts')
            Workbooks               = C 'microsoft.insights/workbooks'
            Dashboards              = C 'microsoft.portal/dashboards'
            Grafana                 = C 'microsoft.dashboard/grafana'
            AutomationAccounts      = C 'microsoft.automation/automationaccounts'
        }
    }
}
