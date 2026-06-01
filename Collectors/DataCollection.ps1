function Get-AerDataCollection {
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
    function Leaf($id) { if ($id) { ($id -split '/')[-1] } else { '' } }
    function FromJson($s) { if ($s -and "$s" -ne 'null') { try { $s | ConvertFrom-Json } catch { $null } } else { $null } }
    function ArgRows($query) { Expand-AerRows (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $query) }

    # ── Data Collection Rules (nested fields projected as JSON strings so the
    #    columnar-safe Expand-AerRows can be used) ─────────────────────────────
    $dcrs = [System.Collections.Generic.List[object]]::new()
    $dcrById = @{}                   # lower id -> dcr record
    $destNodes = [ordered]@{}        # dest node id -> node
    $dcrDestEdges = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($r in (ArgRows @'
resources
| where type =~ 'microsoft.insights/datacollectionrules'
| project id, name, subscriptionId, resourceGroup, location,
          dcrKind = tostring(kind),
          destinations = tostring(properties.destinations),
          dataFlows = tostring(properties.dataFlows),
          dataSources = tostring(properties.dataSources),
          tags = tostring(tags)
'@)) {
            $idl = if ($r.id) { $r.id.ToLowerInvariant() } else { '' }
            $dp = FromJson $r.destinations
            $dests = [System.Collections.Generic.List[object]]::new()
            if ($dp) {
                foreach ($la in @($dp.logAnalytics)) {
                    $tid = ("$($la.workspaceResourceId)").ToLowerInvariant()
                    $nm  = if ($la.workspaceResourceId) { Leaf $la.workspaceResourceId } else { "$($la.name)" }
                    if (-not $nm) { $nm = 'Log Analytics' }
                    $dests.Add([pscustomobject]@{ Type = 'Log Analytics'; Name = $nm })
                    $node = if ($tid) { $tid } else { "la:$nm" }
                    if (-not $destNodes.Contains($node)) { $destNodes[$node] = [pscustomobject]@{ id = $node; name = $nm; type = 'Log Analytics' } }
                    if ($idl) { $dcrDestEdges.Add([pscustomobject]@{ From = $idl; To = $node }) }
                }
                if ($dp.azureMonitorMetrics) {
                    $dests.Add([pscustomobject]@{ Type = 'Azure Monitor Metrics'; Name = 'Azure Monitor Metrics' })
                    if (-not $destNodes.Contains('ammetrics')) { $destNodes['ammetrics'] = [pscustomobject]@{ id = 'ammetrics'; name = 'Azure Monitor Metrics'; type = 'Metrics' } }
                    if ($idl) { $dcrDestEdges.Add([pscustomobject]@{ From = $idl; To = 'ammetrics' }) }
                }
                foreach ($ma in @($dp.monitoringAccounts)) {
                    $tid = ("$($ma.accountResourceId)").ToLowerInvariant(); $nm = if ($ma.accountResourceId) { Leaf $ma.accountResourceId } else { "$($ma.name)" }
                    if (-not $nm) { $nm = 'Azure Monitor Workspace' }
                    $dests.Add([pscustomobject]@{ Type = 'Azure Monitor Workspace'; Name = $nm })
                    $node = if ($tid) { $tid } else { "amw:$nm" }
                    if (-not $destNodes.Contains($node)) { $destNodes[$node] = [pscustomobject]@{ id = $node; name = $nm; type = 'Azure Monitor Workspace' } }
                    if ($idl) { $dcrDestEdges.Add([pscustomobject]@{ From = $idl; To = $node }) }
                }
                foreach ($sa in @($dp.storageAccounts) + @($dp.storageBlobs) + @($dp.storageTablesDirect)) {
                    if (-not $sa) { continue }
                    $tid = ("$($sa.storageAccountResourceId)").ToLowerInvariant(); $nm = if ($sa.storageAccountResourceId) { Leaf $sa.storageAccountResourceId } else { "$($sa.name)" }
                    $dests.Add([pscustomobject]@{ Type = 'Storage'; Name = $nm })
                    $node = if ($tid) { $tid } else { "sa:$nm" }
                    if (-not $destNodes.Contains($node)) { $destNodes[$node] = [pscustomobject]@{ id = $node; name = $nm; type = 'Storage' } }
                    if ($idl) { $dcrDestEdges.Add([pscustomobject]@{ From = $idl; To = $node }) }
                }
                foreach ($eh in @($dp.eventHubs) + @($dp.eventHubsDirect)) {
                    if (-not $eh) { continue }
                    $nm = if ($eh.eventHubResourceId) { Leaf $eh.eventHubResourceId } else { "$($eh.name)" }
                    $dests.Add([pscustomobject]@{ Type = 'Event Hub'; Name = $nm })
                    $node = "eh:$nm"
                    if (-not $destNodes.Contains($node)) { $destNodes[$node] = [pscustomobject]@{ id = $node; name = $nm; type = 'Event Hub' } }
                    if ($idl) { $dcrDestEdges.Add([pscustomobject]@{ From = $idl; To = $node }) }
                }
            }

            $flows = FromJson $r.dataFlows
            $streams = @($flows | ForEach-Object { @($_.streams) } | Where-Object { $_ } | Select-Object -Unique)
            $ds = FromJson $r.dataSources
            $dsKinds = if ($ds) { @($ds.PSObject.Properties.Name) } else { @() }

            $rec = [pscustomobject]@{
                Name = "$($r.name)"; Id = "$($r.id)"
                SubscriptionName = (SubName $r.subscriptionId); ResourceGroup = "$($r.resourceGroup)"; Location = "$($r.location)"
                Kind = if ($r.dcrKind) { "$($r.dcrKind)" } else { 'All' }
                Destinations = @($dests)
                Streams = @($streams)
                DataSourceKinds = @($dsKinds)
                Tags = (FromJson $r.tags)
                MachineCount = 0
            }
            $dcrs.Add($rec)
            if ($idl) { $dcrById[$idl] = $rec }
        }
    } catch { Write-Warning "[DataCollection.dcr] $($_.Exception.Message)" }

    # ── Data Collection Endpoints ────────────────────────────────────────────
    $dces = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($r in (ArgRows "resources | where type =~ 'microsoft.insights/datacollectionendpoints' | project id, name, subscriptionId, resourceGroup, location, tags = tostring(tags)")) {
            $dces.Add([pscustomobject]@{
                Name = "$($r.name)"; Id = "$($r.id)"
                SubscriptionName = (SubName $r.subscriptionId); ResourceGroup = "$($r.resourceGroup)"; Location = "$($r.location)"
                Tags = (FromJson $r.tags)
            })
        }
    } catch { Write-Warning "[DataCollection.dce] $($_.Exception.Message)" }

    # ── Machines (VM + Arc) and AMA extension state ──────────────────────────
    $machineRecs = @{}    # lower id -> record
    try {
        foreach ($m in (ArgRows "resources | where type in~ ('microsoft.compute/virtualmachines','microsoft.hybridcompute/machines') | project id, name, subscriptionId, resourceGroup, location, type = tolower(type)")) {
            if (-not $m.id) { continue }
            $machineRecs[$m.id.ToLowerInvariant()] = [pscustomobject]@{
                Name = "$($m.name)"; Id = "$($m.id)"
                SubscriptionName = (SubName $m.subscriptionId); ResourceGroup = "$($m.resourceGroup)"; Location = "$($m.location)"
                Kind = if ($m.type -like '*hybridcompute*') { 'Arc' } else { 'VM' }
                AmaInstalled = $false; AmaVersion = ''
                Dcrs = [System.Collections.Generic.List[string]]::new()
                Dces = [System.Collections.Generic.List[string]]::new()
            }
        }
        foreach ($e in (ArgRows "resources | where type in~ ('microsoft.compute/virtualmachines/extensions','microsoft.hybridcompute/machines/extensions') | where name has 'AzureMonitorWindowsAgent' or name has 'AzureMonitorLinuxAgent' or tostring(properties.type) in~ ('AzureMonitorWindowsAgent','AzureMonitorLinuxAgent') | project id = tolower(id), ver = tostring(properties.typeHandlerVersion)")) {
            if (-not $e.id) { continue }
            $parent = ($e.id -split '/extensions/')[0]
            if ($parent -and $machineRecs.ContainsKey($parent)) { $machineRecs[$parent].AmaInstalled = $true; $machineRecs[$parent].AmaVersion = "$($e.ver)" }
        }
    } catch { Write-Warning "[DataCollection.machines] $($_.Exception.Message)" }

    # ── DCR associations (DCRA) — not in ARG → ARM batch GET per machine ──────
    $assocCount = 0
    $vmDcrEdges = [System.Collections.Generic.List[object]]::new()
    try {
        $ids = @($machineRecs.Keys)
        if ($ids.Count) {
            $reqs = [System.Collections.Generic.List[object]]::new()
            $nameToId = @{}
            for ($i = 0; $i -lt $ids.Count; $i++) {
                $nameToId[$i.ToString()] = $ids[$i]
                $reqs.Add([ordered]@{ httpMethod = 'GET'; name = $i.ToString(); url = "$($ids[$i])/providers/Microsoft.Insights/dataCollectionRuleAssociations?api-version=2022-06-01" })
            }
            $responses = Invoke-AerArmBatch $reqs
            foreach ($key in $responses.Keys) {
                $rr = $responses[$key]
                if ($rr.httpStatusCode -lt 200 -or $rr.httpStatusCode -ge 300) { continue }
                $mid = $nameToId[$key]; $mrec = $machineRecs[$mid]
                foreach ($a in @($rr.content.value)) {
                    $dcrId = ("$($a.properties.dataCollectionRuleId)").ToLowerInvariant()
                    $dceId = ("$($a.properties.dataCollectionEndpointId)").ToLowerInvariant()
                    if ($dcrId) {
                        $assocCount++
                        $dcr = $dcrById[$dcrId]
                        if ($dcr) { $mrec.Dcrs.Add($dcr.Name); $dcr.MachineCount++ }
                        else { $mrec.Dcrs.Add((Leaf $dcrId)) }
                        $vmDcrEdges.Add([pscustomobject]@{ From = $mid; To = $dcrId })
                    } elseif ($dceId) {
                        $mrec.Dces.Add((Leaf $dceId))
                    }
                }
            }
        }
    } catch { Write-Warning "[DataCollection.dcra] $($_.Exception.Message)" }

    # Finalize machine records (lists → arrays)
    $machines = foreach ($m in $machineRecs.Values) {
        [pscustomobject]@{
            Name = $m.Name; Id = $m.Id; SubscriptionName = $m.SubscriptionName; ResourceGroup = $m.ResourceGroup
            Location = $m.Location; Kind = $m.Kind; AmaInstalled = $m.AmaInstalled; AmaVersion = $m.AmaVersion
            Dcrs = @($m.Dcrs); Dces = @($m.Dces)
        }
    }
    $machines = @($machines)
    $machinesWithAma = @($machines | Where-Object { $_.AmaInstalled }).Count

    # ── Graph (VM | DCR | Destination) — keep only DCR-connected machines ─────
    $usedDcr = @{}; foreach ($e in $vmDcrEdges) { $usedDcr[$e.To] = $true }
    $vmNodes = foreach ($e in ($vmDcrEdges | Sort-Object From -Unique)) {
        $m = $machineRecs[$e.From]
        if ($m) { [pscustomobject]@{ id = $m.Id.ToLowerInvariant(); name = $m.Name; sub = $m.SubscriptionName; rg = $m.ResourceGroup; ama = $m.AmaInstalled } }
    }
    $dcrNodes = foreach ($rec in $dcrs) {
        $idl = $rec.Id.ToLowerInvariant()
        [pscustomobject]@{ id = $idl; name = $rec.Name; sub = $rec.SubscriptionName; rg = $rec.ResourceGroup }
    }

    return [pscustomobject]@{
        Counts = [pscustomobject]@{
            Dcr             = @($dcrs).Count
            Dce             = @($dces).Count
            Machines        = $machines.Count
            MachinesWithAma = $machinesWithAma
            Associations    = $assocCount
        }
        Dcrs     = @($dcrs)
        Dces     = @($dces)
        Machines = $machines
        Graph = [pscustomobject]@{
            Vms          = @($vmNodes)
            Dcrs         = @($dcrNodes)
            Dests        = @($destNodes.Values)
            VmDcrEdges   = @($vmDcrEdges)
            DcrDestEdges = @($dcrDestEdges)
        }
    }
}
