function Get-AerApplications {
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

    # Static type → label/category map (microsoft.web/sites is resolved by kind below)
    $staticMap = @{
        'microsoft.web/serverfarms'                   = @{ Label = 'App Service Plan';         Category = 'Web / App Service' }
        'microsoft.web/hostingenvironments'           = @{ Label = 'App Service Environment';   Category = 'Web / App Service' }
        'microsoft.web/staticsites'                   = @{ Label = 'Static Web App';            Category = 'Web / App Service' }
        'microsoft.logic/workflows'                   = @{ Label = 'Logic App (Consumption)';   Category = 'Functions & Logic' }
        'microsoft.containerservice/managedclusters'  = @{ Label = 'Azure Kubernetes Service';  Category = 'Containers' }
        'microsoft.app/containerapps'                 = @{ Label = 'Container Apps';            Category = 'Containers' }
        'microsoft.app/managedenvironments'           = @{ Label = 'Container Apps Environment'; Category = 'Containers' }
        'microsoft.containerinstance/containergroups' = @{ Label = 'Container Instances';        Category = 'Containers' }
        'microsoft.containerregistry/registries'      = @{ Label = 'Container Registry';         Category = 'Containers' }
        'microsoft.servicefabric/clusters'            = @{ Label = 'Service Fabric';             Category = 'Containers' }
        'microsoft.apimanagement/service'             = @{ Label = 'API Management';             Category = 'API & Integration' }
    }
    function Classify($type, $kind) {
        if ($type -eq 'microsoft.web/sites') {
            $k = "$kind".ToLower()
            if ($k -match 'workflowapp') { return @{ Label = 'Logic App (Standard)';   Category = 'Functions & Logic' } }
            if ($k -match 'functionapp') { return @{ Label = 'Function App';            Category = 'Functions & Logic' } }
            if ($k -match 'container')   { return @{ Label = 'Web App for Containers';   Category = 'Web / App Service' } }
            return @{ Label = 'Web App'; Category = 'Web / App Service' }
        }
        return $staticMap[$type]
    }

    $types = @($staticMap.Keys) + 'microsoft.web/sites'
    $typeList = "'" + ($types -join "','") + "'"
    $query = @"
resources
| where type in~ ($typeList)
| project id, name, type = tolower(type), subscriptionId, resourceGroup, location,
          acctKind = tostring(kind),
          skuTier  = tostring(sku.tier),
          kubeVersion = tostring(properties.kubernetesVersion),
          tags
"@

    $rows = @()
    try { $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $query }
    catch { Write-Warning "[Applications.resources] $($_.Exception.Message)" }

    $byType = @{}; $labelCat = @{}; $byCat = @{}; $byLoc = @{}; $aksVer = @{}; $planTier = @{}

    foreach ($r in $rows) {
        $meta = Classify $r.type $r.acctKind
        if (-not $meta) { continue }
        $label = $meta.Label; $cat = $meta.Category

        $byType[$label]   = ([int]($byType[$label] ?? 0)) + 1
        $labelCat[$label] = $cat
        $byCat[$cat]      = ([int]($byCat[$cat] ?? 0)) + 1
        $loc = if ($r.location) { $r.location } else { '—' }
        $byLoc[$loc]      = ([int]($byLoc[$loc] ?? 0)) + 1

        if ($r.type -eq 'microsoft.containerservice/managedclusters' -and $r.kubeVersion) {
            $v = (($r.kubeVersion -split '\.')[0..1]) -join '.'
            $aksVer[$v] = ([int]($aksVer[$v] ?? 0)) + 1
        } elseif ($r.type -eq 'microsoft.web/serverfarms') {
            $tier = if ($r.skuTier) { $r.skuTier } else { 'Unknown' }
            $planTier[$tier] = ([int]($planTier[$tier] ?? 0)) + 1
        }
    }

    $catOrder = @('Web / App Service', 'Functions & Logic', 'Containers', 'API & Integration')
    $byCategory = foreach ($c in $catOrder) { [pscustomobject]@{ Category = $c; Count = [int]($byCat[$c] ?? 0) } }

    $byTypeList = $byType.GetEnumerator() | Sort-Object Value -Descending |
        ForEach-Object { [pscustomobject]@{ Label = $_.Key; Category = $labelCat[$_.Key]; Count = [int]$_.Value } }
    $byLocation = $byLoc.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 |
        ForEach-Object { [pscustomobject]@{ Region = $_.Key; Count = [int]$_.Value } }
    $aksByVersion = $aksVer.GetEnumerator() | Sort-Object Name -Descending |
        ForEach-Object { [pscustomobject]@{ Version = $_.Key; Count = [int]$_.Value } }
    $plansByTier = $planTier.GetEnumerator() | Sort-Object Value -Descending |
        ForEach-Object { [pscustomobject]@{ Tier = $_.Key; Count = [int]$_.Value } }

    return [pscustomobject]@{
        TotalServices = ($rows | Measure-Object).Count
        Web           = [int]($byCat['Web / App Service'] ?? 0)
        Functions     = [int]($byCat['Functions & Logic'] ?? 0)
        Containers    = [int]($byCat['Containers'] ?? 0)
        Integration   = [int]($byCat['API & Integration'] ?? 0)
        Aks           = [int]($byType['Azure Kubernetes Service'] ?? 0)
        DistinctTypes = @($byTypeList).Count
        ByCategory    = @($byCategory)
        ByType        = @($byTypeList)
        ByLocation    = @($byLocation)
        AksByVersion  = @($aksByVersion)
        PlansByTier   = @($plansByTier)
    }
}
