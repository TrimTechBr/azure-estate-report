function Get-AerGovernance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        [Parameter(Mandatory)]            $SubscriptionMap
    )

    $typeMap = @{
        'microsoft.authorization/policyassignments'    = @{ Label = 'Policy Assignment';      Category = 'Policy' }
        'microsoft.authorization/policydefinitions'    = @{ Label = 'Policy Definition';       Category = 'Policy' }
        'microsoft.authorization/policysetdefinitions' = @{ Label = 'Initiative (Policy Set)'; Category = 'Policy' }
        'microsoft.authorization/roleassignments'      = @{ Label = 'Role Assignment';         Category = 'Access' }
        'microsoft.authorization/roledefinitions'      = @{ Label = 'Custom Role';             Category = 'Access' }
        'microsoft.authorization/locks'                = @{ Label = 'Resource Lock';           Category = 'Access' }
        'microsoft.resources/subscriptions'                = @{ Label = 'Subscription';        Category = 'Organization' }
        'microsoft.resources/subscriptions/resourcegroups' = @{ Label = 'Resource Group';      Category = 'Organization' }
    }

    # Count by type via summarize (returns clean per-type rows). Authorization
    # plane lives in authorizationresources; org scopes in resourcecontainers.
    $cnt = @{}
    function Add-Counts($table, $types) {
        try {
            $tl = "'" + ($types -join "','") + "'"
            $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query "$table | where type in~ ($tl) | summarize c = count() by t = tolower(type)"
            foreach ($r in $rows) { if ($r.t) { $cnt[$r.t] = [int]$r.c } }
        } catch { Write-Warning "[Governance.$table] $($_.Exception.Message)" }
    }
    Add-Counts 'authorizationresources' @(
        'microsoft.authorization/policyassignments', 'microsoft.authorization/policydefinitions',
        'microsoft.authorization/policysetdefinitions', 'microsoft.authorization/roleassignments',
        'microsoft.authorization/roledefinitions', 'microsoft.authorization/locks')
    Add-Counts 'resourcecontainers' @(
        'microsoft.resources/subscriptions', 'microsoft.resources/subscriptions/resourcegroups')

    $byCat = @{}; $byTypeList = [System.Collections.Generic.List[object]]::new()
    foreach ($t in $typeMap.Keys) {
        $n = [int]($cnt[$t] ?? 0)
        if ($n -le 0) { continue }
        $m = $typeMap[$t]
        $byCat[$m.Category] = ([int]($byCat[$m.Category] ?? 0)) + $n
        $byTypeList.Add([pscustomobject]@{ Label = $m.Label; Category = $m.Category; Count = $n })
    }
    $catOrder = @('Policy', 'Access', 'Organization')

    [pscustomobject]@{
        Total         = [int]((@($byTypeList) | Measure-Object Count -Sum).Sum ?? 0)
        DistinctTypes = @($byTypeList).Count
        Categories    = @($catOrder | ForEach-Object { [pscustomobject]@{ Category = $_; Count = [int]($byCat[$_] ?? 0) } })
        ByType        = @($byTypeList | Sort-Object Count -Descending)
        ByLocation    = @()   # governance scopes have no meaningful region
    }
}
