function Get-AerInventory {
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

    $resourceRows = @()
    try {
        $resourceRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| summarize Count=count() by subscriptionId, type, location
'@
    } catch { Write-Warning "[Inventory.resources] $($_.Exception.Message)" }

    $rgRows = @()
    try {
        $rgRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resourcecontainers
| where type == 'microsoft.resources/subscriptions/resourcegroups'
| summarize ResourceGroups=count() by subscriptionId
'@
    } catch { Write-Warning "[Inventory.rgRows] $($_.Exception.Message)" }

    $resourceList = @()
    try {
        $resourceList = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| project id, subscriptionId, resourceGroup, name, type, location,
          provisioningState = tostring(properties.provisioningState), tags
'@
    } catch { Write-Warning "[Inventory.resource-list] $($_.Exception.Message)" }

    $managementGroupCount = 0
    try {
        $mgResp = Invoke-AzRestMethod -Method GET `
            -Path '/providers/Microsoft.Management/managementGroups?api-version=2020-05-01' `
            -ErrorAction Stop
        if ($mgResp.StatusCode -eq 200) {
            $managementGroupCount = @(($mgResp.Content | ConvertFrom-Json).value).Count
        }
    } catch { }

    $totalResources = ($resourceRows | Measure-Object -Property Count -Sum).Sum ?? 0
    $totalRG        = ($rgRows       | Measure-Object -Property ResourceGroups -Sum).Sum ?? 0

    $bySubscription = $resourceRows |
        Group-Object subscriptionId |
        ForEach-Object {
            $sid   = $_.Name
            $count = ($_.Group | Measure-Object -Property Count -Sum).Sum
            $sname = if ($sid) { $subLookup[$sid.ToLowerInvariant()] } else { $null }
            [pscustomobject]@{
                SubscriptionId   = $sid
                SubscriptionName = $sname ?? $sid
                Count            = [int]$count
            }
        } | Sort-Object Count -Descending

    $byType = $resourceRows |
        Group-Object type |
        ForEach-Object {
            [pscustomobject]@{
                Type  = ($_.Name -split '/')[-1]
                Count = [int]($_.Group | Measure-Object -Property Count -Sum).Sum
            }
        } | Sort-Object Count -Descending | Select-Object -First 10

    $byRegion = $resourceRows |
        Group-Object location |
        ForEach-Object {
            [pscustomobject]@{
                Region = $_.Name
                Count  = [int]($_.Group | Measure-Object -Property Count -Sum).Sum
            }
        } | Sort-Object Count -Descending | Select-Object -First 5

    return [pscustomobject]@{
        ManagementGroups    = $managementGroupCount
        Subscriptions       = $SubscriptionIds.Count
        TotalResourceGroups = [int]$totalRG
        TotalResources      = [int]$totalResources
        BySubscription      = @($bySubscription)
        ByType              = @($byType)
        ByRegion            = @($byRegion)
        SubscriptionMap     = $subLookup
        ResourceList        = @($resourceList)
    }
}
