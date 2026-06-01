function Get-AerCloudStructure {
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

    # Per-subscription resource and resource-group counts (via ARG)
    $resCount = @{}
    $rgCount  = @{}
    try {
        $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| summarize Count=count() by subscriptionId
'@
        foreach ($r in $rows) { if ($r.subscriptionId) { $resCount[$r.subscriptionId.ToLowerInvariant()] = [int]$r.Count } }
    } catch { Write-Warning "[CloudStructure.resCount] $($_.Exception.Message)" }
    try {
        $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resourcecontainers
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| summarize Count=count() by subscriptionId
'@
        foreach ($r in $rows) { if ($r.subscriptionId) { $rgCount[$r.subscriptionId.ToLowerInvariant()] = [int]$r.Count } }
    } catch { Write-Warning "[CloudStructure.rgCount] $($_.Exception.Message)" }

    $mgs     = [System.Collections.Generic.List[object]]::new()
    $subToMg = @{}

    try {
        $listResp = Invoke-AzRestMethod -Method GET `
            -Path '/providers/Microsoft.Management/managementGroups?api-version=2020-05-01' `
            -ErrorAction Stop
        if ($listResp.StatusCode -eq 200) {
            $list = @(($listResp.Content | ConvertFrom-Json).value)
            foreach ($mg in $list) {
                $name       = $mg.name
                $display    = $mg.properties.displayName ?? $name
                $parentName  = ''
                $childSubs   = [System.Collections.Generic.List[string]]::new()
                $childGroups = [System.Collections.Generic.List[string]]::new()
                try {
                    $detResp = Invoke-AzRestMethod -Method GET `
                        -Path "/providers/Microsoft.Management/managementGroups/$($name)?api-version=2020-05-01&`$expand=children" `
                        -ErrorAction Stop
                    if ($detResp.StatusCode -eq 200) {
                        $det        = $detResp.Content | ConvertFrom-Json
                        $parent     = $det.properties.details.parent
                        $parentName = $parent.displayName ?? $parent.name ?? ''
                        foreach ($child in @($det.properties.children)) {
                            if ($child.type -match 'subscriptions') {
                                $cid = $child.name.ToLowerInvariant()
                                $subToMg[$cid] = $display
                                $childSubs.Add($subLookup[$cid] ?? $child.displayName ?? $child.name)
                            } elseif ($child.type -match 'managementGroups') {
                                $childGroups.Add($child.displayName ?? $child.name)
                            }
                        }
                    }
                } catch { }
                $mgs.Add([pscustomobject]@{
                    Id            = $name
                    Name          = $display
                    Parent        = $parentName
                    ChildGroups   = @($childGroups)
                    Subscriptions = @($childSubs)
                })
            }
        }
    } catch {
        Write-Warning "[CloudStructure.mgs] $($_.Exception.Message)"
    }

    $subs = foreach ($kv in $subLookup.GetEnumerator()) {
        [pscustomobject]@{
            Id                 = $kv.Key
            Name               = $kv.Value
            ManagementGroup    = $subToMg[$kv.Key] ?? ''
            ResourceGroupCount = $rgCount[$kv.Key] ?? 0
            ResourceCount      = $resCount[$kv.Key] ?? 0
        }
    }

    return [pscustomobject]@{
        ManagementGroups = @($mgs | Sort-Object Name)
        Subscriptions    = @($subs | Sort-Object Name)
    }
}
