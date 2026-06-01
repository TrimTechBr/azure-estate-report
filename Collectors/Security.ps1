function Get-AerSecurityGaps {
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

    # Each check = an ARG heuristic over the resource graph. Base yields the
    # affected resources; Count is computed exactly, Resources capped at 200.
    $checks = @(
        @{ Severity = 'Critical'; Title = 'Storage accounts with public access enabled'; ResourceType = 'microsoft.storage/storageaccounts'
           Base = "resources | where type =~ 'microsoft.storage/storageaccounts' | where properties.allowBlobPublicAccess == true" }
        @{ Severity = 'High'; Title = 'NSGs with inbound Any/Any rules'; ResourceType = 'microsoft.network/networksecuritygroups'
           Base = "resources | where type =~ 'microsoft.network/networksecuritygroups' | mv-expand rule=properties.securityRules | where rule.properties.direction == 'Inbound' and rule.properties.sourceAddressPrefix == '*' and rule.properties.destinationAddressPrefix == '*' | summarize by id, name, type, resourceGroup, subscriptionId" }
        @{ Severity = 'Medium'; Title = 'VMs without AMA or MDE extension'; ResourceType = 'microsoft.compute/virtualmachines'
           Base = "resources | where type =~ 'microsoft.compute/virtualmachines' | extend vmId = tolower(id) | join kind=leftanti (resources | where type =~ 'microsoft.compute/virtualmachines/extensions' | where name startswith 'AzureMonitor' or name startswith 'MDE' | extend vmId = tolower(tostring(split(id, '/extensions/')[0])) | distinct vmId) on vmId" }
        @{ Severity = 'Info'; Title = 'Key Vaults with soft-delete disabled'; ResourceType = 'microsoft.keyvault/vaults'
           Base = "resources | where type =~ 'microsoft.keyvault/vaults' | where properties.enableSoftDelete != true" }
    )

    $severityOrder = @{ Critical = 0; High = 1; Medium = 2; Info = 3 }
    $items = foreach ($check in $checks) {
        $d = Get-CheckData $check.Base
        [pscustomobject]@{
            Severity     = $check.Severity
            Title        = $check.Title
            ResourceType = $check.ResourceType
            Count        = $d.Count
            Resources    = @($d.Resources)
        }
    }
    $sorted = $items | Sort-Object { $severityOrder[$_.Severity] }

    return [pscustomobject]@{
        TotalGaps = ($items | Measure-Object -Property Count -Sum).Sum
        Items     = @($sorted)
    }
}
