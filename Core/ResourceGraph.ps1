function Invoke-AerArgQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]   $Query,
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        [int] $PageSize = 1000
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $skip = 0

    do {
        $params = @{
            Query        = $Query
            Subscription = $SubscriptionIds
            First        = $PageSize
            ErrorAction  = 'Stop'
        }
        if ($skip -gt 0) { $params['Skip'] = $skip }

        $page = @(Search-AzGraph @params)
        $allResults.AddRange($page)
        $skip += $page.Count
    } while ($page.Count -eq $PageSize)

    return @($allResults)
}

# Search-AzGraph intermittently returns a single *columnar* object (each
# projected column as a parallel array) instead of one object per row. For
# scalar-only projections, any array-valued property is the columnar tell →
# transpose back into per-row objects. NOTE: only safe for scalar projections;
# do NOT use on queries that legitimately return array-valued columns (e.g. a
# single VNet row with an addressPrefixes/subnets array) — it would explode them.
function Expand-AerRows {
    param($Result)
    $rows = @($Result)
    if ($rows.Count -ne 1 -or -not $rows[0] -or -not $rows[0].PSObject) { return $rows }
    $c = $rows[0]
    $arrProps = @($c.PSObject.Properties | Where-Object { $_.Value -is [System.Array] })
    if ($arrProps.Count -eq 0) { return $rows }
    $n = @($arrProps[0].Value).Count
    $names = $c.PSObject.Properties.Name
    $expanded = for ($i = 0; $i -lt $n; $i++) {
        $o = [ordered]@{}
        foreach ($nm in $names) { $v = $c.$nm; $o[$nm] = if ($v -is [System.Array]) { $v[$i] } else { $v } }
        [pscustomobject]$o
    }
    return @($expanded)
}

# ARM batch REST runner — chunks requests (≤20 per call) and returns a
# name → response map. Each request is [ordered]@{ httpMethod; name; url }.
function Invoke-AerArmBatch {
    param([System.Collections.Generic.List[object]] $Requests)
    $out = @{}
    for ($i = 0; $i -lt $Requests.Count; $i += 20) {
        $end   = [math]::Min($i + 19, $Requests.Count - 1)
        $chunk = $Requests[$i..$end]
        $payload = @{ requests = @($chunk) } | ConvertTo-Json -Depth 5
        try {
            $resp = Invoke-AzRestMethod -Method POST -Uri "https://management.azure.com/batch?api-version=2020-06-01" -Payload $payload
            foreach ($rr in @(($resp.Content | ConvertFrom-Json).responses)) { $out[[string]$rr.name] = $rr }
        } catch { Write-Warning "[Aer.armBatch] $($_.Exception.Message)" }
    }
    return $out
}

# Format a subnet resource id as "vnet / subnet" (case-insensitive). Returns ''
# when no subnet id is present — used to surface VNet integration on resources.
function Get-AerSubnetLabel {
    param([string] $SubnetId)
    if (-not $SubnetId) { return '' }
    $vnet = if ($SubnetId -match '/virtualNetworks/([^/]+)') { $matches[1] } else { '' }
    $sub  = if ($SubnetId -match '/subnets/([^/]+)')         { $matches[1] } else { '' }
    if ($vnet -and $sub) { "$vnet / $sub" } elseif ($vnet) { $vnet } else { '' }
}

# Aggregate ARG rows (each with .type lowercased + optional .location) into the
# standard category-overview shape used by the section Overview pages.
function Get-AerTypeAggregate {
    [CmdletBinding()]
    param(
        $Rows,
        [hashtable] $TypeMap,
        [string[]]  $CategoryOrder
    )
    $byType = @{}; $labelCat = @{}; $byCat = @{}; $byLoc = @{}; $total = 0
    foreach ($r in @($Rows)) {
        $meta = $TypeMap[$r.type]
        if (-not $meta) { continue }
        $total++
        $label = $meta.Label; $cat = $meta.Category
        $byType[$label]   = ([int]($byType[$label] ?? 0)) + 1
        $labelCat[$label] = $cat
        $byCat[$cat]      = ([int]($byCat[$cat] ?? 0)) + 1
        $loc = if ($r.location) { $r.location } else { '—' }
        $byLoc[$loc]      = ([int]($byLoc[$loc] ?? 0)) + 1
    }
    $cats = if ($CategoryOrder) { $CategoryOrder } else { @($byCat.Keys | Sort-Object) }
    $categories = foreach ($c in $cats) { [pscustomobject]@{ Category = $c; Count = [int]($byCat[$c] ?? 0) } }
    $byTypeList = $byType.GetEnumerator() | Sort-Object Value -Descending |
        ForEach-Object { [pscustomobject]@{ Label = $_.Key; Category = $labelCat[$_.Key]; Count = [int]$_.Value } }
    $byLocation = $byLoc.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 |
        ForEach-Object { [pscustomobject]@{ Region = $_.Key; Count = [int]$_.Value } }

    [pscustomobject]@{
        Total         = $total
        DistinctTypes = @($byTypeList).Count
        Categories    = @($categories)
        ByType        = @($byTypeList)
        ByLocation    = @($byLocation)
    }
}
