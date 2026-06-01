function Get-AerDiagnosticSettings {
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
    function SubName($id) { if (-not $id) { return 'Unknown' }; $n = $subLookup[$id.ToLowerInvariant()]; if ($n) { $n } else { $id } }
    function Pctg($part, $total) { if ($total -gt 0) { [int][math]::Round($part / $total * 100) } else { $null } }
    function Leaf($id) { if ($id) { ($id -split '/')[-1] } else { '' } }
    function NsOf($id) {
        if (-not $id) { return '' }
        $parts = $id -split '/'; $i = [array]::IndexOf($parts, 'namespaces')
        if ($i -ge 0 -and ($i + 1) -lt $parts.Count) { $parts[$i + 1] } else { '' }
    }
    function ArgRows($query) { Expand-AerRows (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $query) }

    # Curated set of resource types that support diagnostic settings and where
    # log/metric forwarding is meaningful. VMs/disks/NICs are excluded (they use
    # the agent model, not diagnosticSettings).
    $diagTypes = @(
        'microsoft.keyvault/vaults','microsoft.storage/storageaccounts',
        'microsoft.web/sites','microsoft.web/serverfarms',
        'microsoft.sql/servers/databases','microsoft.sql/managedinstances',
        'microsoft.documentdb/databaseaccounts',
        'microsoft.dbforpostgresql/flexibleservers','microsoft.dbformysql/flexibleservers',
        'microsoft.network/applicationgateways','microsoft.network/loadbalancers',
        'microsoft.network/publicipaddresses','microsoft.network/networksecuritygroups',
        'microsoft.network/azurefirewalls','microsoft.network/frontdoors',
        'microsoft.cdn/profiles','microsoft.network/virtualnetworkgateways',
        'microsoft.network/expressroutecircuits','microsoft.network/bastionhosts',
        'microsoft.apimanagement/service','microsoft.servicebus/namespaces',
        'microsoft.eventhub/namespaces','microsoft.eventgrid/topics',
        'microsoft.eventgrid/systemtopics','microsoft.cache/redis',
        'microsoft.containerservice/managedclusters','microsoft.automation/automationaccounts',
        'microsoft.logic/workflows','microsoft.datafactory/factories',
        'microsoft.operationalinsights/workspaces','microsoft.recoveryservices/vaults',
        'microsoft.search/searchservices','microsoft.signalrservice/signalr',
        'microsoft.cognitiveservices/accounts','microsoft.streamanalytics/streamingjobs',
        'microsoft.batch/batchaccounts','microsoft.machinelearningservices/workspaces'
    )

    $totalAll = 0
    try { $totalAll = (@(ArgRows "resources | project id = tolower(id)")).Count } catch {}

    $resources = [System.Collections.Generic.List[object]]::new()
    $evaluated = 0; $enabled = 0
    $bySub  = @{}   # subId -> @{ Total; Covered }
    $noDiag = @{}   # type  -> count without diag settings

    try {
        $diagList = "'" + ($diagTypes -join "','") + "'"
        $targets = @(ArgRows "resources | where type in~ ($diagList) | project id, name, type = tolower(type), subscriptionId, resourceGroup, location, tags")

        # Index targets by request name so batch responses can be matched back.
        $reqs = [System.Collections.Generic.List[object]]::new()
        $meta = [System.Collections.Generic.List[object]]::new()
        foreach ($t in $targets) {
            if (-not $t.id) { continue }
            $meta.Add($t)
            $reqs.Add([ordered]@{
                httpMethod = 'GET'
                name       = ($meta.Count - 1).ToString()
                url        = "$($t.id)/providers/microsoft.insights/diagnosticSettings?api-version=2021-05-01-preview"
            })
        }

        $responses = if ($reqs.Count) { Invoke-AerArmBatch $reqs } else { @{} }

        foreach ($key in $responses.Keys) {
            $rr = $responses[$key]; $t = $meta[[int]$key]
            if ($rr.httpStatusCode -lt 200 -or $rr.httpStatusCode -ge 300) { continue }   # type unsupported / no permission
            $evaluated++
            $subId = ("$($t.subscriptionId)").ToLowerInvariant()
            if (-not $bySub.ContainsKey($subId)) { $bySub[$subId] = @{ Total = 0; Covered = 0 } }
            $bySub[$subId].Total++

            $settingsRaw = @($rr.content.value)
            $isOn = $settingsRaw.Count -gt 0
            $destSet = [ordered]@{}
            $settings = foreach ($s in $settingsRaw) {
                $p = $s.properties
                $la = if ($p.workspaceId) { Leaf $p.workspaceId } else { '' }
                $sa = if ($p.storageAccountId) { Leaf $p.storageAccountId } else { '' }
                $eh = if ($p.eventHubAuthorizationRuleId) { $n = NsOf $p.eventHubAuthorizationRuleId; if ($p.eventHubName) { "$n / $($p.eventHubName)" } else { $n } } else { '' }
                $tp = if ($p.marketplacePartnerId) { Leaf $p.marketplacePartnerId } else { '' }
                if ($la) { $destSet['Log Analytics'] = $true }
                if ($sa) { $destSet['Storage'] = $true }
                if ($eh) { $destSet['Event Hub'] = $true }
                if ($tp) { $destSet['Third-party'] = $true }

                $logsOn = @(); $logsOff = @()
                foreach ($l in @($p.logs)) {
                    $cat = if ($l.category) { "$($l.category)" } elseif ($l.categoryGroup) { "$($l.categoryGroup)" } else { 'log' }
                    if ($l.enabled) { $logsOn += $cat } else { $logsOff += $cat }
                }
                $metOn = @(); $metOff = @()
                foreach ($m in @($p.metrics)) {
                    $cat = if ($m.category) { "$($m.category)" } else { 'AllMetrics' }
                    if ($m.enabled) { $metOn += $cat } else { $metOff += $cat }
                }
                [pscustomobject]@{
                    Name           = "$($s.name)"
                    LogAnalytics   = $la
                    Storage        = $sa
                    EventHub       = $eh
                    ThirdParty     = $tp
                    LogsEnabled    = @($logsOn)
                    LogsDisabled   = @($logsOff)
                    MetricsEnabled = @($metOn)
                    MetricsDisabled= @($metOff)
                }
            }

            if ($isOn) { $enabled++; $bySub[$subId].Covered++ }
            else { $noDiag[$t.type] = ([int]($noDiag[$t.type] ?? 0)) + 1 }

            $resources.Add([pscustomobject]@{
                Name             = "$($t.name)"
                Type             = ($t.type -replace '^microsoft\.', '')
                SubscriptionName = (SubName $t.subscriptionId)
                ResourceGroup    = "$($t.resourceGroup)"
                Location         = "$($t.location)"
                Id               = "$($t.id)"
                Tags             = $t.tags
                Enabled          = $isOn
                Destinations     = @($destSet.Keys)
                Settings         = @($settings)
            })
        }
    } catch { Write-Warning "[DiagnosticSettings] $($_.Exception.Message)" }

    $coverageBySub = $bySub.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{ Subscription = (SubName $_.Key); Total = $_.Value.Total; Covered = $_.Value.Covered; Percent = (Pctg $_.Value.Covered $_.Value.Total) }
    } | Sort-Object Total -Descending

    $topNoDiag = $noDiag.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8 | ForEach-Object {
        [pscustomobject]@{ Type = ($_.Key -replace '^microsoft\.', ''); Count = $_.Value }
    }

    return [pscustomobject]@{
        Summary = [pscustomobject]@{
            TotalResources = $totalAll
            Evaluated      = $evaluated
            Enabled        = $enabled
            Percent        = (Pctg $enabled $evaluated)
        }
        CoverageBySubscription = @($coverageBySub)
        TopTypesWithoutDiag    = @($topNoDiag)
        Resources              = @($resources)
    }
}
