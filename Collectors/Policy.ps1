function Get-AerPolicy {
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
    function Pctg($part, $total) { if ($total -gt 0) { [int][math]::Round($part / $total * 100) } else { $null } }
    function FromJson($s) { if ($s -and "$s" -ne 'null') { try { $s | ConvertFrom-Json } catch { $null } } else { $null } }
    function Leaf($id) { if ($id) { ($id -split '/')[-1] } else { '' } }
    function EffName($a) {
        switch ($a) {
            'audit'             { 'Audit' }            'deny'             { 'Deny' }
            'denyaction'        { 'DenyAction' }       'deployifnotexists' { 'DeployIfNotExists' }
            'auditifnotexists'  { 'AuditIfNotExists' } 'modify'           { 'Modify' }
            'append'            { 'Append' }           'disabled'         { 'Disabled' }
            'manual'            { 'Manual' }           'addtonetworkgroup' { 'AddToNetworkGroup' }
            default { if ($a) { (($a.Substring(0,1)).ToUpper() + $a.Substring(1)) } else { 'Unknown' } }
        }
    }
    function ScopeLabel($scope) {
        $s = "$scope"
        if (-not $s) { return '' }
        if ($s -match '/managementGroups/([^/]+)') { return 'Management Group: ' + $matches[1] }
        $sub = if ($s -match '/subscriptions/([^/]+)') { $matches[1] } else { '' }
        $rg  = if ($s -match '/resourceGroups/([^/]+)') { $matches[1] } else { '' }
        $subName = if ($sub) { $subLookup[$sub.ToLowerInvariant()] ?? $sub } else { '' }
        if ($rg)  { return "Resource Group: $rg" + $(if ($subName) { " ($subName)" } else { '' }) }
        if ($sub) { return "Subscription: $subName" }
        return $s
    }

    # Policy assignments / definitions live at subscription AND management-group
    # scope. Invoke-AerArgQuery restricts to subscriptions, which drops MG-scoped
    # assignments — so query the ARG REST endpoint WITHOUT a subscription filter
    # (resultFormat=objectArray also sidesteps the columnar quirk).
    function ArgAll($query) {
        $rows = [System.Collections.Generic.List[object]]::new()
        $skipToken = $null
        do {
            $opts = @{ resultFormat = 'objectArray'; '$top' = 1000 }
            if ($skipToken) { $opts['$skipToken'] = $skipToken }
            $body = @{ query = $query; options = $opts } | ConvertTo-Json -Depth 5
            try {
                $r = Invoke-AzRestMethod -Method POST -Uri "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Payload $body
                if ($r.StatusCode -lt 200 -or $r.StatusCode -ge 300) { break }
                $j = $r.Content | ConvertFrom-Json
                foreach ($d in @($j.data)) { $rows.Add($d) }
                $skipToken = $j.'$skipToken'
            } catch { Write-Warning "[Policy.arg] $($_.Exception.Message)"; break }
        } while ($skipToken)
        return @($rows)
    }

    # ── Policy & initiative definitions (name resolution + initiative members) ─
    $defName = @{}
    try {
        foreach ($d in (ArgAll "policyresources | where type =~ 'microsoft.authorization/policydefinitions' | project id = tolower(id), dn = tostring(properties.displayName)")) {
            if ($d.id) { $defName[$d.id] = if ($d.dn) { "$($d.dn)" } else { (Leaf $d.id) } }
        }
    } catch { Write-Warning "[Policy.defs] $($_.Exception.Message)" }
    $setMembers = @{}; $setRefMap = @{}
    try {
        foreach ($s in (ArgAll "policyresources | where type =~ 'microsoft.authorization/policysetdefinitions' | project id = tolower(id), dn = tostring(properties.displayName), policyDefs = tostring(properties.policyDefinitions)")) {
            if (-not $s.id) { continue }
            $defName[$s.id] = if ($s.dn) { "$($s.dn)" } else { (Leaf $s.id) }
            $members = [System.Collections.Generic.List[string]]::new()
            $refMap = @{}
            foreach ($pd in @(FromJson $s.policyDefs)) {
                $pdId = ("$($pd.policyDefinitionId)").ToLowerInvariant()
                $nm = $defName[$pdId] ?? (Leaf $pdId)
                $members.Add($nm)
                $ref = "$($pd.policyDefinitionReferenceId)"
                if ($ref) { $refMap[$ref] = $nm }
            }
            $setMembers[$s.id] = @($members)
            $setRefMap[$s.id] = $refMap
        }
    } catch { Write-Warning "[Policy.sets] $($_.Exception.Message)" }

    # ── Assignments (unscoped → includes MG scope) ───────────────────────────
    $assignments = [System.Collections.Generic.List[object]]::new()
    $policyAssign = 0; $initiativeAssign = 0
    try {
        foreach ($a in (ArgAll @'
policyresources
| where type =~ 'microsoft.authorization/policyassignments'
| project id, name,
          dn = tostring(properties.displayName),
          defId = tostring(properties.policyDefinitionId),
          scope = tostring(properties.scope),
          enforcementMode = tostring(properties.enforcementMode),
          parameters = tostring(properties.parameters),
          identityType = tostring(identity.type)
'@)) {
            $defIdL = ("$($a.defId)").ToLowerInvariant()
            $isInit = $defIdL -like '*/policysetdefinitions/*'
            if ($isInit) { $initiativeAssign++ } else { $policyAssign++ }
            $members = if ($isInit) { @($setMembers[$defIdL]) } else { @() }
            $defDisplay = $defName[$defIdL] ?? (Leaf $defIdL)
            $params = FromJson $a.parameters
            $paramList = @()
            if ($params) {
                foreach ($p in $params.PSObject.Properties) {
                    $val = $p.Value.value
                    if ($val -is [System.Array]) { $val = ($val -join ', ') }
                    $paramList += [pscustomobject]@{ Name = $p.Name; Value = "$val" }
                }
            }
            $assignments.Add([pscustomobject]@{
                Id               = "$($a.id)"
                Key              = ("$($a.id)").ToLowerInvariant()
                DefIdL           = $defIdL
                Name             = if ($a.dn) { "$($a.dn)" } else { "$($a.name)" }
                Type             = if ($isInit) { 'Initiative' } else { 'Policy' }
                Definition       = $defDisplay
                Scope            = (ScopeLabel ($a.scope ? $a.scope : $a.id))
                EnforcementMode  = if ($a.enforcementMode) { "$($a.enforcementMode)" } else { 'Default' }
                IdentityType     = if ($a.identityType -and $a.identityType -ne 'None') { "$($a.identityType)" } else { '' }
                Members          = @($members)
                Parameters       = @($paramList)
                Compliant        = 0
                NonCompliant     = 0
                Conflict         = 0
            })
        }
    } catch { Write-Warning "[Policy.assignments] $($_.Exception.Message)" }
    $assignByKey = @{}; foreach ($a in $assignments) { $assignByKey[$a.Key] = $a }

    # ── Policy exemptions (unscoped → includes MG scope) ─────────────────────
    $exemptions = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($e in (ArgAll @'
policyresources
| where type =~ 'microsoft.authorization/policyexemptions'
| project id, name,
          dn = tostring(properties.displayName),
          assignmentId = tostring(properties.policyAssignmentId),
          category = tostring(properties.exemptionCategory),
          expiresOn = tostring(properties.expiresOn),
          description = tostring(properties.description),
          refIds = tostring(properties.policyDefinitionReferenceIds),
          selectors = tostring(properties.resourceSelectors),
          createdBy = tostring(systemData.createdBy),
          createdByType = tostring(systemData.createdByType)
'@)) {
            $aKey = ("$($e.assignmentId)").ToLowerInvariant()
            $assign = $assignByKey[$aKey]
            $assignName = if ($assign) { $assign.Name } else { (Leaf $e.assignmentId) }
            $refIds = @(FromJson $e.refIds)
            $refMap = if ($assign -and $assign.DefIdL) { $setRefMap[$assign.DefIdL] } else { $null }
            $appliesTo = if (@($refIds).Count -eq 0) {
                @('All policies in the assignment')
            } else {
                @($refIds | ForEach-Object { if ($refMap -and $refMap.ContainsKey("$_")) { $refMap["$_"] } else { "$_" } })
            }
            $selList = @()
            foreach ($s in @(FromJson $e.selectors)) {
                foreach ($sel in @($s.selectors)) {
                    $vals = @(@($sel.in) + @($sel.notIn) | Where-Object { $_ })
                    $selList += "$($sel.kind): " + (@($vals) -join ', ')
                }
            }
            $expRaw = $e.expiresOn
            $expStr = if ($expRaw -is [datetime]) { $expRaw.ToString('yyyy-MM-dd') } elseif ($expRaw) { ("$expRaw" -replace 'T.*$', '') } else { '' }
            $expired = if ($expRaw) { try { ([datetime]$expRaw) -lt (Get-Date) } catch { $false } } else { $false }
            $exemptions.Add([pscustomobject]@{
                Name          = if ($e.dn) { "$($e.dn)" } else { "$($e.name)" }
                Assignment    = $assignName
                Scope         = (ScopeLabel $e.id)
                Category      = if ($e.category) { "$($e.category)" } else { '' }
                CreatedBy     = "$($e.createdBy)"
                CreatedByType = "$($e.createdByType)"
                ExpiresOn     = $expStr
                Expired       = $expired
                Description   = "$($e.description)"
                ReferenceIds  = @($refIds)
                AppliesTo     = @($appliesTo)
                ResourceSelectors = @($selList)
                Id            = "$($e.id)"
            })
        }
    } catch { Write-Warning "[Policy.exemptions] $($_.Exception.Message)" }

    # ── Remediation: non-compliant resources under DINE/Modify + recent tasks ─
    $remGroups = @{}          # key -> { Policy; Assignment; Scope; Resources(List) }
    $remResources = @{}       # distinct non-compliant remediable resourceIds
    $remTasks = [System.Collections.Generic.List[object]]::new()
    foreach ($sub in $SubscriptionIds) {
        # Remediable non-compliant resources (one page, up to 1000)
        try {
            $filter = "ComplianceState eq 'NonCompliant' and (PolicyDefinitionAction eq 'deployifnotexists' or PolicyDefinitionAction eq 'modify')"
            $select = "resourceId,policyAssignmentId,policyAssignmentName,policyAssignmentScope,policyDefinitionName,policyDefinitionReferenceId"
            $uri = "https://management.azure.com/subscriptions/$sub/providers/Microsoft.PolicyInsights/policyStates/latest/queryResults?api-version=2019-10-01&`$top=1000&`$filter=" + [uri]::EscapeDataString($filter) + "&`$select=" + [uri]::EscapeDataString($select)
            $resp = Invoke-AzRestMethod -Method POST -Uri $uri
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                foreach ($row in @(($resp.Content | ConvertFrom-Json).value)) {
                    $rid = "$($row.resourceId)"
                    if ($rid) { $remResources[$rid.ToLowerInvariant()] = $true }
                    $aId = "$($row.policyAssignmentId)"
                    $ref = "$($row.policyDefinitionReferenceId)"
                    $key = ($aId + '|' + $ref).ToLowerInvariant()
                    if (-not $remGroups.ContainsKey($key)) {
                        $remGroups[$key] = [pscustomobject]@{
                            Policy     = $(if ($row.policyDefinitionName) { "$($row.policyDefinitionName)" } elseif ($ref) { $ref } else { 'Policy' })
                            Assignment = $(if ($row.policyAssignmentName) { "$($row.policyAssignmentName)" } else { (Leaf $aId) })
                            Scope      = (ScopeLabel ($row.policyAssignmentScope ? $row.policyAssignmentScope : $aId))
                            Resources  = [System.Collections.Generic.List[string]]::new()
                        }
                    }
                    if ($rid -and $remGroups[$key].Resources.Count -lt 500) { $remGroups[$key].Resources.Add((Leaf $rid)) }
                }
            }
        } catch { Write-Warning "[Policy.remediable:$sub] $($_.Exception.Message)" }

        # Remediation tasks
        try {
            $resp = Invoke-AzRestMethod -Method GET -Uri "https://management.azure.com/subscriptions/$sub/providers/Microsoft.PolicyInsights/remediations?api-version=2021-10-01&`$top=20"
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                foreach ($t in @(($resp.Content | ConvertFrom-Json).value)) {
                    $ds = $t.properties.deploymentStatus
                    $remTasks.Add([pscustomobject]@{
                        Name       = "$($t.name)"
                        Assignment = (Leaf $t.properties.policyAssignmentId)
                        Policy     = $(if ($t.properties.policyDefinitionReferenceId) { "$($t.properties.policyDefinitionReferenceId)" } else { '—' })
                        Scope      = (ScopeLabel $t.id)
                        State      = "$($t.properties.provisioningState)"
                        Total      = [int]($ds.totalDeployments ?? 0)
                        Succeeded  = [int]($ds.successfulDeployments ?? 0)
                        Failed     = [int]($ds.failedDeployments ?? 0)
                        CreatedOn  = $t.properties.createdOn
                    })
                }
            }
        } catch { Write-Warning "[Policy.remediations:$sub] $($_.Exception.Message)" }
    }
    $remItems = $remGroups.Values | ForEach-Object {
        [pscustomobject]@{ Policy = $_.Policy; Assignment = $_.Assignment; Scope = $_.Scope; ResourceCount = @($_.Resources).Count; Resources = @($_.Resources) }
    } | Sort-Object ResourceCount -Descending
    $remTasksTop = @($remTasks | Sort-Object { try { [datetime]$_.CreatedOn } catch { [datetime]::MinValue } } -Descending | Select-Object -First 10 |
        ForEach-Object { $_.CreatedOn = $(if ($_.CreatedOn -is [datetime]) { $_.CreatedOn.ToString('yyyy-MM-dd HH:mm') } elseif ($_.CreatedOn) { ("$($_.CreatedOn)" -replace 'T', ' ' -replace 'Z$', '' -replace '\..*$', '') } else { '' }); $_ })

    # ── Compliance / pending / effects + per-assignment states (Policy Insights)
    $compliant = 0; $nonCompliant = 0; $conflict = 0; $pending = 0
    $effects = @{}; $effectSeen = @{}
    $remediable = @('deployifnotexists', 'modify')
    foreach ($sub in $SubscriptionIds) {
        try {
            $apply = 'groupby((policyAssignmentId,complianceState,policyDefinitionAction),aggregate($count as count))'
            $uri = "https://management.azure.com/subscriptions/$sub/providers/Microsoft.PolicyInsights/policyStates/latest/queryResults?api-version=2019-10-01&`$apply=" + [uri]::EscapeDataString($apply)
            $r = Invoke-AzRestMethod -Method POST -Uri $uri
            if ($r.StatusCode -lt 200 -or $r.StatusCode -ge 300) { continue }
            foreach ($row in @(($r.Content | ConvertFrom-Json).value)) {
                $aid = ("$($row.policyAssignmentId)").ToLowerInvariant()
                $cs  = "$($row.complianceState)"
                $act = ("$($row.policyDefinitionAction)").ToLowerInvariant()
                $cnt = [int]$row.count
                if     ($cs -eq 'Compliant')    { $compliant += $cnt }
                elseif ($cs -eq 'NonCompliant') { $nonCompliant += $cnt; if ($remediable -contains $act) { $pending += $cnt } }
                elseif ($cs -eq 'Conflict')     { $conflict += $cnt }
                # effects: distinct assignment × effect (dedupe across subscriptions)
                if ($act) {
                    $ek = "$aid|$act"
                    if (-not $effectSeen.ContainsKey($ek)) { $effectSeen[$ek] = $true; $effects[$act] = ([int]($effects[$act] ?? 0)) + 1 }
                }
                # per-assignment rollup
                $rec = $assignByKey[$aid]
                if ($rec) {
                    if     ($cs -eq 'Compliant')    { $rec.Compliant += $cnt }
                    elseif ($cs -eq 'NonCompliant') { $rec.NonCompliant += $cnt }
                    elseif ($cs -eq 'Conflict')     { $rec.Conflict += $cnt }
                }
            }
        } catch { Write-Warning "[Policy.compliance:$sub] $($_.Exception.Message)" }
    }

    # Finalize assignment rows (compliance status + percent)
    $items = foreach ($a in $assignments) {
        $tot = $a.Compliant + $a.NonCompliant + $a.Conflict
        [pscustomobject]@{
            Name              = $a.Name
            Type              = $a.Type
            Definition        = $a.Definition
            Scope             = $a.Scope
            Id                = $a.Id
            Compliant         = ($a.NonCompliant + $a.Conflict) -eq 0 -and $tot -gt 0
            Evaluated         = ($tot -gt 0)
            CompliancePercent = (Pctg $a.Compliant $tot)
            CompliantCount    = $a.Compliant
            NonCompliantCount = $a.NonCompliant
            EnforcementMode   = $a.EnforcementMode
            IdentityType      = $a.IdentityType
            Members           = @($a.Members)
            Parameters        = @($a.Parameters)
        }
    }
    $items = @($items) | Sort-Object @{ E = { $_.NonCompliantCount }; Descending = $true }, Name

    $evaluated = $compliant + $nonCompliant + $conflict
    $effectsByType = $effects.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        [pscustomobject]@{ Effect = (EffName $_.Key); Count = [int]$_.Value }
    }

    return [pscustomobject]@{
        Compliance = [pscustomobject]@{
            Compliant = $compliant; NonCompliant = $nonCompliant; Conflict = $conflict
            Evaluated = $evaluated; OverallPercent = (Pctg $compliant $evaluated)
        }
        Assignments = [pscustomobject]@{ Policy = $policyAssign; Initiative = $initiativeAssign; Total = $policyAssign + $initiativeAssign }
        PendingRemediation = $pending
        EffectsByType      = @($effectsByType)
        Items              = @($items)
        Exemptions         = @($exemptions)
        Remediation = [pscustomobject]@{
            PoliciesToRemediate  = @($remItems).Count
            ResourcesToRemediate = $remResources.Count
            Items                = @($remItems)
            Tasks                = @($remTasksTop)
        }
    }
}
