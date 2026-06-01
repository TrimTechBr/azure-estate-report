function Get-AerAdvisorSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds
    )

    $allRecs    = [System.Collections.Generic.List[object]]::new()
    $categories = @('Security', 'Reliability', 'Cost', 'Performance', 'OperationalExcellence')

    foreach ($subId in $SubscriptionIds) {
        $path = "/subscriptions/$subId/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&`$top=1000"
        while (-not [string]::IsNullOrWhiteSpace($path)) {
            try {
                $resp = Invoke-AzRestMethod -Method GET -Path $path -ErrorAction Stop
                if ($resp.StatusCode -ne 200) { break }
                $parsed = $resp.Content | ConvertFrom-Json
                $path   = if ($parsed.nextLink) { ([uri]$parsed.nextLink).PathAndQuery } else { $null }
                foreach ($rec in $parsed.value) { $allRecs.Add($rec) }
            } catch { break }
        }
    }

    $highImpact = @($allRecs | Where-Object { $_.properties.impact -eq 'High' })

    $byCategory = $categories | ForEach-Object {
        $cat   = $_
        $count = @($allRecs | Where-Object { $_.properties.category -eq $cat }).Count
        [pscustomobject]@{ Category = $cat; Count = $count }
    }

    $recommendations = foreach ($r in $allRecs) {
        $p   = $r.properties
        $rid = $p.resourceMetadata.resourceId
        $sid = if ($rid -match '/subscriptions/([^/]+)') { $matches[1] } else { '' }
        [pscustomobject]@{
            Category       = $p.category
            Impact         = $p.impact
            Problem        = $p.shortDescription.problem
            Solution       = $p.shortDescription.solution
            Resource       = $p.impactedValue
            ResourceType   = $p.impactedField
            ResourceId     = $rid
            SubscriptionId = $sid
        }
    }

    return [pscustomobject]@{
        TotalRecommendations = $allRecs.Count
        HighImpactCount      = $highImpact.Count
        ByCategory           = @($byCategory)
        Recommendations      = @($recommendations)
    }
}
