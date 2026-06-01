function Get-AerDefender {
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
    function ResScope($resId) {
        $s = "$resId"
        $sub = if ($s -match '/subscriptions/([^/]+)') { $matches[1] } else { '' }
        $rg  = if ($s -match '/resourceGroups/([^/]+)') { $matches[1] } else { '' }
        $subName = if ($sub) { $subLookup[$sub.ToLowerInvariant()] ?? $sub } else { '' }
        if ($rg)  { "$rg ($subName)" } elseif ($subName) { $subName } else { $s }
    }
    function NormRisk($risk, $sev) {
        $r = if ($risk) { "$risk" } elseif ($sev) { "$sev" } else { '' }
        switch -regex ($r) { '^Critical' { 'Critical' } '^High' { 'High' } '^Medium' { 'Medium' } '^Low' { 'Low' } default { if ($r) { $r } else { 'Unknown' } } }
    }

    # ── Security assessments (recommendations) — scalar projections so the
    #    columnar-safe ArgRows can be used ─────────────────────────────────────
    $recs = [System.Collections.Generic.List[object]]::new()
    $healthy = 0; $unhealthy = 0; $na = 0
    $sev = [ordered]@{ Critical = 0; High = 0; Medium = 0; Low = 0 }
    try {
        foreach ($a in (ArgRows @'
securityresources
| where type =~ 'microsoft.security/assessments'
| project id,
          status = tostring(properties.status.code),
          statusDesc = tostring(properties.status.description),
          severity = tostring(properties.metadata.severity),
          riskLevel = tostring(properties.risk.level),
          riskFactors = tostring(properties.risk.riskFactors),
          title = tostring(properties.displayName),
          remediation = tostring(properties.metadata.remediationDescription),
          statusChange = tostring(properties.status.statusChangeDate)
'@)) {
            $st = "$($a.status)"
            if     ($st -eq 'Healthy')        { $healthy++ }
            elseif ($st -eq 'Unhealthy')      { $unhealthy++ }
            elseif ($st -eq 'NotApplicable')  { $na++ }
            $risk = NormRisk $a.riskLevel $a.severity
            if ($st -eq 'Unhealthy' -and $sev.Contains($risk)) { $sev[$risk]++ }
            $resId = ("$($a.id)" -split '(?i)/providers/microsoft.security/assessments/')[0]
            $resName = if ($resId -match '^/subscriptions/([^/]+)/?$') { 'Subscription: ' + (SubName $matches[1]) } else { (Leaf $resId) }
            $rf = @(FromJson $a.riskFactors | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($_.title) { "$($_.title)" } elseif ($_.type) { "$($_.type)" } else { "$_" } })
            $chRaw = $a.statusChange
            $chStr = if ($chRaw -is [datetime]) { $chRaw.ToString('yyyy-MM-dd') } elseif ($chRaw) { ("$chRaw" -replace 'T.*$', '') } else { '' }
            $recs.Add([pscustomobject]@{
                RiskLevel   = $risk
                Title       = if ($a.title) { "$($a.title)" } else { (Leaf $a.id) }
                Resource    = $resName
                ResourceId  = $resId
                Status      = $st
                Scope       = (ResScope $resId)
                LastChange  = $chStr
                RiskFactors = @($rf)
                Remediation = "$($a.remediation)"
                Description = "$($a.statusDesc)"
            })
        }
    } catch { Write-Warning "[Defender.assessments] $($_.Exception.Message)" }

    # ── Defender plans (pricings) per subscription via REST ──────────────────
    $subs = [System.Collections.Generic.List[object]]::new()
    foreach ($sid in $SubscriptionIds) {
        try {
            $r = Invoke-AzRestMethod -Method GET -Uri "https://management.azure.com/subscriptions/$sid/providers/Microsoft.Security/pricings?api-version=2024-01-01"
            if ($r.StatusCode -lt 200 -or $r.StatusCode -ge 300) { continue }
            $plans = foreach ($p in @(($r.Content | ConvertFrom-Json).value)) {
                $tier = "$($p.properties.pricingTier)"
                $active = $tier -eq 'Standard'
                $exts = foreach ($e in @($p.properties.extensions)) {
                    if (-not $e) { continue }
                    [pscustomobject]@{ Name = "$($e.name)"; Enabled = ($e.isEnabled -eq $true -or "$($e.isEnabled)" -eq 'True') }
                }
                $exts = @($exts)
                $partial = $active -and (@($exts | Where-Object { -not $_.Enabled }).Count -gt 0)
                [pscustomobject]@{
                    Name = "$($p.name)"; Tier = $tier; SubPlan = "$($p.properties.subPlan)"
                    Active = $active; Partial = $partial; Extensions = $exts
                }
            }
            $plans = @($plans)
            $subs.Add([pscustomobject]@{
                Subscription  = (SubName $sid)
                StandardCount = @($plans | Where-Object { $_.Active }).Count
                FreeCount     = @($plans | Where-Object { -not $_.Active }).Count
                Total         = $plans.Count
                Plans         = $plans
            })
        } catch { Write-Warning "[Defender.pricings:$sid] $($_.Exception.Message)" }
    }

    return [pscustomobject]@{
        Summary = [pscustomobject]@{
            Total = $healthy + $unhealthy + $na
            Healthy = $healthy; Unhealthy = $unhealthy; NotApplicable = $na
        }
        SeverityCounts = [pscustomobject]@{ Critical = $sev.Critical; High = $sev.High; Medium = $sev.Medium; Low = $sev.Low }
        Recommendations = @($recs)
        Subscriptions   = @($subs)
    }
}
