function Get-AerCostWaste {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        $SubscriptionMap
    )

    $subLookup = @{}
    if ($SubscriptionMap -is [hashtable]) { $subLookup = $SubscriptionMap }
    elseif ($SubscriptionMap) { $SubscriptionMap.PSObject.Properties | ForEach-Object { $subLookup[$_.Name] = $_.Value } }
    function SubName($id) { if (-not $id) { return '' }; $n = $subLookup[$id.ToLowerInvariant()]; if ($n) { $n } else { $id } }
    function ArgRows($q) { Expand-AerRows (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $q) }
    function Get-CheckData($base) {
        $count = 0; $res = @()
        try { $c = @(ArgRows "$base | summarize Count=count()"); if ($c -and $null -ne $c[0].Count) { $count = [int]$c[0].Count } } catch { }
        try {
            $res = @(ArgRows "$base | project id, name, type=tolower(type), resourceGroup, subscriptionId | limit 200" | ForEach-Object {
                [pscustomobject]@{ Name = "$($_.name)"; Type = ("$($_.type)" -replace '^microsoft\.', ''); ResourceGroup = "$($_.resourceGroup)"; SubscriptionName = (SubName $_.subscriptionId); Id = "$($_.id)" }
            })
        } catch { }
        return @{ Count = $count; Resources = $res }
    }

    # Each check = an ARG heuristic for idle/orphaned resources that typically
    # incur cost without delivering value. Base yields the affected resources.
    $checks = @(
        @{ Title = 'Orphaned managed disks'; ResourceType = 'microsoft.compute/disks'; Note = 'Not attached to any VM'
           Base = "resources | where type =~ 'microsoft.compute/disks' | where isnull(managedBy) or managedBy == ''" }
        @{ Title = 'Unassociated public IP addresses'; ResourceType = 'microsoft.network/publicipaddresses'; Note = 'Not linked to any resource'
           Base = "resources | where type =~ 'microsoft.network/publicipaddresses' | where isnull(properties.ipConfiguration)" }
        @{ Title = 'Stopped VMs still provisioned'; ResourceType = 'microsoft.compute/virtualmachines'; Note = 'Deallocated but still incurring storage costs'
           Base = "resources | where type =~ 'microsoft.compute/virtualmachines' | where properties.extended.instanceView.powerState.code =~ 'PowerState/deallocated'" }
        @{ Title = 'Empty App Service Plans'; ResourceType = 'microsoft.web/serverfarms'; Note = 'No apps deployed'
           Base = "resources | where type =~ 'microsoft.web/serverfarms' | where properties.numberOfSites == 0" }
        @{ Title = 'Load balancers with no backend pools'; ResourceType = 'microsoft.network/loadbalancers'; Note = 'Idle, no backend configured'
           Base = "resources | where type =~ 'microsoft.network/loadbalancers' | where array_length(properties.backendAddressPools) == 0" }
    )

    $items = foreach ($check in $checks) {
        $d = Get-CheckData $check.Base
        [pscustomobject]@{
            Title        = $check.Title
            ResourceType = $check.ResourceType
            Note         = $check.Note
            Count        = $d.Count
            Resources    = @($d.Resources)
        }
    }

    return [pscustomobject]@{
        TotalWastedResources = ($items | Measure-Object -Property Count -Sum).Sum
        Items                = @($items | Sort-Object Count -Descending)
    }
}
