function Get-AerObsInventory {
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
    function FromJson($s) { if ($s -and "$s" -ne 'null') { try { $s | ConvertFrom-Json } catch { $null } } else { $null } }
    function ArgRows($query) { Expand-AerRows (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $query) }

    # ── App Insights components → which workspaces they use, and total count ──
    $usedWs = @{}; $aiCount = 0
    try {
        foreach ($c in (ArgRows "resources | where type =~ 'microsoft.insights/components' | project ws = tolower(tostring(properties.WorkspaceResourceId))")) {
            $aiCount++
            if ($c.ws) { $usedWs[$c.ws] = $true }
        }
    } catch { Write-Warning "[ObsInventory.components] $($_.Exception.Message)" }

    # ── Log Analytics data export rules → workspaces exporting to a storage acct
    $exportByWs = @{}
    try {
        foreach ($e in (ArgRows "resources | where type =~ 'microsoft.operationalinsights/workspaces/dataexports' | project id = tolower(id), destId = tolower(tostring(properties.destination.resourceId)), enabled = tostring(properties.enable)")) {
            if (-not $e.id) { continue }
            $ws = ($e.id -split '/dataexports/')[0]
            $isStorage = $e.destId -and ($e.destId -like '*/storageaccounts/*')
            if ($ws -and $isStorage) { $exportByWs[$ws] = $true }
        }
    } catch { Write-Warning "[ObsInventory.dataexports] $($_.Exception.Message)" }

    # ── Log Analytics workspaces ─────────────────────────────────────────────
    $workspaces = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($w in (ArgRows @'
resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| project id, name, subscriptionId, resourceGroup, location,
          retention = toint(properties.retentionInDays),
          skuName = tostring(properties.sku.name),
          dailyQuotaGb = todouble(properties.workspaceCapping.dailyQuotaGb),
          ingestionMode = tostring(properties.publicNetworkAccessForIngestion),
          tags = tostring(tags)
'@)) {
            $idl = if ($w.id) { $w.id.ToLowerInvariant() } else { '' }
            $quota = [double]$w.dailyQuotaGb
            $workspaces.Add([pscustomobject]@{
                Name             = "$($w.name)"; Id = "$($w.id)"
                SubscriptionName = (SubName $w.subscriptionId); ResourceGroup = "$($w.resourceGroup)"; Location = "$($w.location)"
                Retention        = [int]$w.retention
                Sku              = if ($w.skuName) { "$($w.skuName)" } else { '' }
                DailyQuotaGb     = if ($quota -gt 0) { $quota } else { $null }   # -1 / 0 ⇒ unlimited
                IngestionAccess  = "$($w.ingestionMode)"
                UsedByAppInsights = [bool]($idl -and $usedWs[$idl])
                ExportToStorage  = [bool]($idl -and $exportByWs[$idl])
                Tags             = (FromJson $w.tags)
            })
        }
    } catch { Write-Warning "[ObsInventory.workspaces] $($_.Exception.Message)" }

    return [pscustomobject]@{
        Counts = [pscustomobject]@{
            Workspaces  = @($workspaces).Count
            AppInsights = $aiCount
        }
        Workspaces = @($workspaces)
    }
}
