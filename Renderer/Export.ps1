function ConvertTo-AerArray {
    param($Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    return @($Value)
}

function Get-AerValue {
    param(
        $Object,
        [string] $Name,
        $Default = $null
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) { return $Default }
    if ($Object -is [hashtable] -and $Object.ContainsKey($Name)) { return $Object[$Name] }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }

    return $Default
}

function Get-AerFirstValue {
    param(
        $Object,
        [string[]] $Names,
        $Default = $null
    )

    foreach ($name in $Names) {
        $value = Get-AerValue -Object $Object -Name $name -Default $null
        if ($null -ne $value -and "$value" -ne '') { return $value }
    }

    return $Default
}

function Get-AerSubscriptionName {
    param(
        $ReportData,
        [string] $SubscriptionId
    )

    if ([string]::IsNullOrWhiteSpace($SubscriptionId)) { return '' }

    $inv = Get-AerValue -Object $ReportData -Name 'inventory'
    $map = Get-AerValue -Object $inv -Name 'SubscriptionMap'
    $key = $SubscriptionId.ToLowerInvariant()

    if ($map -is [hashtable] -and $map.ContainsKey($key)) { return $map[$key] }
    if ($map -and $map.PSObject.Properties[$key]) { return $map.PSObject.Properties[$key].Value }

    return $SubscriptionId
}

function Get-AerResourceGroupFromId {
    param([string] $ResourceId)

    if ([string]::IsNullOrWhiteSpace($ResourceId)) { return '' }
    if ($ResourceId -match '/resourceGroups/([^/]+)') { return [Uri]::UnescapeDataString($matches[1]) }
    return ''
}

function Get-AerSubscriptionIdFromResourceId {
    param([string] $ResourceId)

    if ([string]::IsNullOrWhiteSpace($ResourceId)) { return '' }
    if ($ResourceId -match '/subscriptions/([^/]+)') { return $matches[1] }
    return ''
}

function Get-AerFindingAffectedType {
    param($Finding)

    Get-AerFirstValue -Object $Finding -Names @('AffectedType', 'ResourceType', 'Type', 'AffectedResourceType') -Default ''
}

function Get-AerAdvisorRecommendationText {
    param($Recommendation)

    Get-AerFirstValue -Object $Recommendation -Names @('Recommendation', 'Problem', 'DisplayName', 'ShortDescription', 'Description', 'Solution') -Default ''
}

function Get-AerAdvisorResourceName {
    param($Recommendation)

    Get-AerFirstValue -Object $Recommendation -Names @('ResourceName', 'Resource', 'ImpactedValue', 'Name') -Default ''
}

function Get-AerAdvisorResourceGroup {
    param($Recommendation)

    $direct = Get-AerFirstValue -Object $Recommendation -Names @('ResourceGroup', 'ResourceGroupName') -Default ''
    if ($direct) { return $direct }

    return Get-AerResourceGroupFromId -ResourceId (Get-AerFirstValue -Object $Recommendation -Names @('ResourceId', 'Id') -Default '')
}

function Get-AerAdvisorSubscriptionName {
    param(
        $ReportData,
        $Recommendation
    )

    $direct = Get-AerFirstValue -Object $Recommendation -Names @('SubscriptionName', 'Subscription') -Default ''
    if ($direct) { return $direct }

    $subId = Get-AerFirstValue -Object $Recommendation -Names @('SubscriptionId', 'subscriptionId') -Default ''
    if (-not $subId) {
        $subId = Get-AerSubscriptionIdFromResourceId -ResourceId (Get-AerFirstValue -Object $Recommendation -Names @('ResourceId', 'Id') -Default '')
    }

    return Get-AerSubscriptionName -ReportData $ReportData -SubscriptionId $subId
}

function Format-AerExportValue {
    param($Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [bool]) { return $(if ($Value) { 'Yes' } else { 'No' }) }
    if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd HH:mm:ss') }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [decimal] -or $Value -is [double] -or $Value -is [single]) {
        return $Value
    }
    if ($Value -is [hashtable]) {
        return (($Value.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ')
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) { $items += "$(Format-AerExportValue $item)" }
        return ($items | Where-Object { $_ -ne '' }) -join '; '
    }

    $label = Get-AerValue -Object $Value -Name 'label'
    $val = Get-AerValue -Object $Value -Name 'value'
    if ($label -and $null -ne $val) { return "${label}: $(Format-AerExportValue $val)" }

    $parts = @()
    foreach ($p in @($Value.PSObject.Properties | Select-Object -First 8)) {
        if ($p.Name -and $null -ne $p.Value -and "$($p.Value)" -ne '') {
            $parts += "$($p.Name)=$(Format-AerExportValue $p.Value)"
        }
    }
    if ($parts.Count -gt 0) { return ($parts -join '; ') }

    return "$Value"
}

function New-AerCell {
    param(
        $Value,
        [string] $Style = 'cell'
    )

    [pscustomobject]@{ Value = $Value; Style = $Style }
}

function New-AerSheetRow {
    param([object[]] $Cells)
    return ,@($Cells)
}

function ConvertTo-AerColumnLetter {
    param([int] $Index)

    $n = $Index
    $letters = ''
    while ($n -gt 0) {
        $m = ($n - 1) % 26
        $letters = [char](65 + $m) + $letters
        $n = [math]::Floor(($n - $m) / 26)
    }
    return $letters
}

function ConvertTo-AerXmlText {
    param($Value)

    return [System.Security.SecurityElement]::Escape("$(Format-AerExportValue $Value)")
}

function Limit-AerText {
    param(
        $Value,
        [int] $Max = 80
    )

    $text = "$(Format-AerExportValue $Value)"
    $text = ($text -replace '\s+', ' ').Trim()
    if ($text.Length -le $Max) { return $text }
    return $text.Substring(0, [math]::Max(0, $Max - 1)) + '…'
}

function New-AerSimpleWorkbookSheet {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Title,
        [string] $Subtitle = '',
        [Parameter(Mandatory)] [object[]] $Columns,
        [object[]] $Items = @()
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $colCount = [math]::Max(1, @($Columns).Count)

    $rows.Add((New-AerSheetRow -Cells @((New-AerCell $Title 'title'))))
    $rows.Add((New-AerSheetRow -Cells @((New-AerCell $Subtitle 'subtitle'))))
    $rows.Add((New-AerSheetRow -Cells @((New-AerCell '' 'default'))))
    $rows.Add((New-AerSheetRow -Cells @($Columns | ForEach-Object { New-AerCell $_.Header 'header' })))

    $data = ConvertTo-AerArray $Items
    if ($data.Count -eq 0) {
        $rows.Add((New-AerSheetRow -Cells @((New-AerCell 'No data available' 'muted'))))
    } else {
        foreach ($item in $data) {
            $cells = @()
            foreach ($col in $Columns) {
                $value = if ($col.PSObject.Properties['Expression']) {
                    & $col.Expression $item
                } else {
                    Get-AerValue -Object $item -Name $col.Key
                }
                $style = if ($value -is [byte] -or $value -is [int16] -or $value -is [int32] -or $value -is [int64] -or
                    $value -is [decimal] -or $value -is [double] -or $value -is [single]) { 'number' } else { 'cell' }
                $cells += New-AerCell $value $style
            }
            $rows.Add((New-AerSheetRow -Cells $cells))
        }
    }

    $mergeLast = ConvertTo-AerColumnLetter $colCount
    [pscustomobject]@{
        Name       = $Name
        Rows       = $rows
        Merges     = @("A1:$mergeLast`1", "A2:$mergeLast`2")
        AutoFilter = "A4:$mergeLast$($rows.Count)"
        FreezeRow  = 4
        ColWidths  = @($Columns | ForEach-Object { if ($_.Width) { [double]$_.Width } else { 18 } })
    }
}

function Get-AerExecutiveMetrics {
    param($ReportData)

    $inv = Get-AerValue $ReportData 'inventory'
    $vm = Get-AerValue $ReportData 'virtualMachines'
    $db = Get-AerValue $ReportData 'databases'
    $adv = Get-AerValue $ReportData 'advisor'
    $pol = Get-AerValue $ReportData 'policy'
    $def = Get-AerValue $ReportData 'defender'
    $cost = Get-AerValue $ReportData 'cost'
    $sec = Get-AerValue $ReportData 'security'
    $errors = ConvertTo-AerArray (Get-AerValue $ReportData 'collectionErrors')

    @(
        [pscustomobject]@{ Metric = 'Subscriptions'; Value = (Get-AerValue $inv 'Subscriptions' 0); Signal = 'Scope' }
        [pscustomobject]@{ Metric = 'Resource groups'; Value = (Get-AerValue $inv 'TotalResourceGroups' 0); Signal = 'Estate size' }
        [pscustomobject]@{ Metric = 'Resources'; Value = (Get-AerValue $inv 'TotalResources' 0); Signal = 'Estate size' }
        [pscustomobject]@{ Metric = 'Virtual machines'; Value = (Get-AerValue $vm 'TotalVMs' 0); Signal = 'Compute' }
        [pscustomobject]@{ Metric = 'Databases'; Value = (Get-AerValue $db 'TotalServices' 0); Signal = 'Data services' }
        [pscustomobject]@{ Metric = 'Advisor recommendations'; Value = (Get-AerValue $adv 'TotalRecommendations' 0); Signal = 'Optimization' }
        [pscustomobject]@{ Metric = 'Policy assignments'; Value = (Get-AerValue (Get-AerValue $pol 'Assignments') 'Total' 0); Signal = 'Governance' }
        [pscustomobject]@{ Metric = 'Defender unhealthy'; Value = (Get-AerValue (Get-AerValue $def 'Summary') 'Unhealthy' 0); Signal = 'Security posture' }
        [pscustomobject]@{ Metric = 'Cost findings'; Value = (Get-AerValue $cost 'TotalWastedResources' 0); Signal = 'Cost optimization' }
        [pscustomobject]@{ Metric = 'General findings'; Value = (Get-AerValue $sec 'TotalGaps' 0); Signal = 'Risk' }
        [pscustomobject]@{ Metric = 'Collection errors'; Value = $errors.Count; Signal = $(if ($errors.Count -eq 0) { 'Healthy' } else { 'Needs review' }) }
    )
}

function Get-AerExecutiveSignals {
    param($ReportData)

    $sec = Get-AerValue $ReportData 'security'
    $cost = Get-AerValue $ReportData 'cost'
    $adv = Get-AerValue $ReportData 'advisor'
    $diag = Get-AerValue $ReportData 'diagnosticSettings'
    $def = Get-AerValue $ReportData 'defender'
    $errors = ConvertTo-AerArray (Get-AerValue $ReportData 'collectionErrors')

    $diagPct = Get-AerValue (Get-AerValue $diag 'Summary') 'Percent' $null
    $defUnhealthy = Get-AerValue (Get-AerValue $def 'Summary') 'Unhealthy' 0

    @(
        [pscustomobject]@{ Area = 'Security'; Signal = "$(Get-AerValue $sec 'TotalGaps' 0) general findings"; Status = $(if ((Get-AerValue $sec 'TotalGaps' 0) -gt 0) { 'Attention' } else { 'Good' }); Action = 'Review general and Defender recommendations' }
        [pscustomobject]@{ Area = 'Cost'; Signal = "$(Get-AerValue $cost 'TotalWastedResources' 0) waste opportunities"; Status = $(if ((Get-AerValue $cost 'TotalWastedResources' 0) -gt 0) { 'Opportunity' } else { 'Good' }); Action = 'Prioritize quick savings and right-sizing' }
        [pscustomobject]@{ Area = 'Advisor'; Signal = "$(Get-AerValue $adv 'TotalRecommendations' 0) recommendations"; Status = $(if ((Get-AerValue $adv 'HighImpactCount' 0) -gt 0) { 'High impact' } else { 'Review' }); Action = 'Sort by impact and category' }
        [pscustomobject]@{ Area = 'Observability'; Signal = $(if ($null -ne $diagPct) { "$diagPct% diagnostic coverage" } else { 'Coverage unavailable' }); Status = $(if ($null -ne $diagPct -and $diagPct -ge 80) { 'Good' } else { 'Attention' }); Action = 'Close diagnostic settings and AMA gaps' }
        [pscustomobject]@{ Area = 'Defender'; Signal = "$defUnhealthy unhealthy assessments"; Status = $(if ($defUnhealthy -gt 0) { 'Attention' } else { 'Good' }); Action = 'Review unhealthy controls by risk' }
        [pscustomobject]@{ Area = 'Collection'; Signal = "$($errors.Count) errors"; Status = $(if ($errors.Count -eq 0) { 'Healthy' } else { 'Partial' }); Action = $(if ($errors.Count -eq 0) { 'No action required' } else { 'Inspect Collection Errors tab' }) }
    )
}

function Get-AerServiceRows {
    param(
        $Container,
        [string] $Family
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $Container) { return @() }

    foreach ($prop in @($Container.PSObject.Properties)) {
        $services = ConvertTo-AerArray (Get-AerValue -Object $prop.Value -Name 'Services')
        foreach ($svc in $services) {
            $rows.Add([pscustomobject]@{
                Family           = if ($Family) { $Family } else { $prop.Name }
                Type             = Get-AerFirstValue $svc @('Type', 'type')
                Name             = Get-AerFirstValue $svc @('Name', 'name')
                SubscriptionName = Get-AerFirstValue $svc @('SubscriptionName', 'subscriptionName')
                ResourceGroup    = Get-AerFirstValue $svc @('ResourceGroup', 'resourceGroup')
                Location         = Get-AerFirstValue $svc @('Location', 'location')
                Status           = Get-AerFirstValue $svc @('Status', 'status', 'ProvisioningState', 'provisioningState')
                Details          = Format-AerExportValue (Get-AerValue $svc 'Details')
                Id               = Get-AerFirstValue $svc @('Id', 'id')
            })
        }
    }

    return @($rows)
}

function New-AerDashboardWideRow {
    param(
        [hashtable] $CellsByColumn,
        [int] $ColumnCount = 16,
        [string] $DefaultStyle = 'default'
    )

    $cells = for ($i = 1; $i -le $ColumnCount; $i++) {
        if ($CellsByColumn.ContainsKey($i)) { $CellsByColumn[$i] } else { New-AerCell '' $DefaultStyle }
    }
    New-AerSheetRow -Cells $cells
}

function Set-AerDashboardSpan {
    param(
        [hashtable] $Map,
        [int] $Start,
        [int] $End,
        [string] $Style,
        $Value = ''
    )

    for ($col = $Start; $col -le $End; $col++) {
        $Map[$col] = New-AerCell '' $Style
    }
    $Map[$Start] = New-AerCell $Value $Style
}

function Get-AerResourceTypeCount {
    param(
        $ReportData,
        [scriptblock] $Predicate
    )

    $inv = Get-AerValue $ReportData 'inventory'
    $resources = ConvertTo-AerArray (Get-AerValue $inv 'ResourceList')
    return @($resources | Where-Object {
        $type = "$(Get-AerFirstValue $_ @('type', 'Type'))".ToLowerInvariant()
        & $Predicate $type
    }).Count
}

function Get-AerResourceDomainRows {
    param($ReportData)

    $inv = Get-AerValue $ReportData 'inventory'
    $resources = ConvertTo-AerArray (Get-AerValue $inv 'ResourceList')
    $counts = [ordered]@{
        Network            = 0
        Databases          = 0
        Applications       = 0
        'Virtual Machines' = 0
        'Storage Accounts' = 0
        Observability      = 0
        Governance         = 0
        Other              = 0
    }

    foreach ($resource in $resources) {
        $type = "$(Get-AerFirstValue $resource @('type', 'Type'))".ToLowerInvariant()
        $domain = if ($type -match 'microsoft\.network/') {
            'Network'
        } elseif ($type -match 'microsoft\.(sql|documentdb|dbforpostgresql|dbformysql|cache|synapse|kusto|databricks|analysisservices)/') {
            'Databases'
        } elseif ($type -match 'microsoft\.(web|app|containerservice|containerinstance|containerregistry|apimanagement|logic|servicebus|eventhub)/') {
            'Applications'
        } elseif ($type -match 'microsoft\.compute/(virtualmachines|virtualmachinescalesets)') {
            'Virtual Machines'
        } elseif ($type -match 'microsoft\.storage/storageaccounts') {
            'Storage Accounts'
        } elseif ($type -match 'microsoft\.(operationalinsights|insights|monitor|alertsmanagement|dashboard|grafana)/') {
            'Observability'
        } elseif ($type -match 'microsoft\.(authorization|policyinsights|security)/') {
            'Governance'
        } else {
            'Other'
        }
        $counts[$domain]++
    }

    $counts.GetEnumerator() |
        Where-Object { $_.Value -gt 0 } |
        Sort-Object Value -Descending |
        ForEach-Object { [pscustomobject]@{ Item = $_.Key; Count = [int]$_.Value } }
}

function New-AerDashboardBar {
    param(
        [int] $Count,
        [int] $Max,
        [int] $Width = 18
    )

    if ($Max -le 0 -or $Count -le 0) { return '' }
    $blocks = [math]::Max(1, [math]::Round(($Count / $Max) * $Width))
    return ('█' * [int]$blocks)
}

function New-AerDashboardDistributionRows {
    param(
        [object[]] $Rows,
        [int] $Top = 7
    )

    $data = @(ConvertTo-AerArray $Rows | Where-Object { (Get-AerValue $_ 'Count' 0) -gt 0 } | Select-Object -First $Top)
    $total = [double](($data | Measure-Object -Property Count -Sum).Sum ?? 0)
    $max = [int](($data | Measure-Object -Property Count -Maximum).Maximum ?? 0)

    foreach ($row in $data) {
        $count = [int](Get-AerValue $row 'Count' 0)
        $pct = if ($total -gt 0) { '{0:0.0}%' -f (($count / $total) * 100) } else { '0.0%' }
        [pscustomobject]@{
            Item  = Get-AerFirstValue $row @('Item', 'Type', 'Label', 'SubscriptionName', 'SubscriptionId', 'Region') ''
            Count = $count
            Pct   = $pct
            Bar   = New-AerDashboardBar -Count $count -Max $max
        }
    }
}

function Group-AerDashboardCountRows {
    param(
        [object[]] $Items,
        [string] $Key,
        [scriptblock] $Label = $null,
        [int] $Top = 7
    )

    $rows = ConvertTo-AerArray $Items
    $grouped = $rows |
        Group-Object {
            $value = if ($Label) { & $Label $_ } else { Get-AerValue $_ $Key }
            if ([string]::IsNullOrWhiteSpace("$value")) { 'Unknown' } else { "$value" }
        } |
        Sort-Object Count -Descending |
        Select-Object -First $Top |
        ForEach-Object { [pscustomobject]@{ Item = $_.Name; Count = [int]$_.Count } }

    return @($grouped)
}

function Group-AerDashboardSumRows {
    param(
        [object[]] $Items,
        [string] $Key,
        [string] $SumKey,
        [int] $Top = 7
    )

    $rows = ConvertTo-AerArray $Items
    $grouped = $rows |
        Group-Object {
            $value = Get-AerValue $_ $Key
            if ([string]::IsNullOrWhiteSpace("$value")) { 'Unknown' } else { "$value" }
        } |
        ForEach-Object {
            [pscustomobject]@{
                Item  = $_.Name
                Count = [int](($_.Group | Measure-Object -Property $SumKey -Sum).Sum ?? 0)
            }
        } |
        Sort-Object Count -Descending |
        Select-Object -First $Top

    return @($grouped)
}

function New-AerDashboardKvRows {
    param([object[]] $Pairs)

    foreach ($pair in (ConvertTo-AerArray $Pairs)) {
        [pscustomobject]@{
            Item  = Get-AerValue $pair 'Item' ''
            Count = Get-AerValue $pair 'Count' ''
        }
    }
}

function Add-AerDashboardThreeBlocks {
    param(
        [System.Collections.Generic.List[object]] $Rows,
        [object[]] $Blocks,
        [int] $Height = 8
    )

    $starts = @(1, 6, 11)
    $titleMap = @{}
    for ($b = 0; $b -lt $Blocks.Count; $b++) {
        Set-AerDashboardSpan -Map $titleMap -Start $starts[$b] -End ($starts[$b] + 3) -Style 'dashTableTitle' -Value $Blocks[$b].Title
    }
    $Rows.Add((New-AerDashboardWideRow $titleMap))

    $headerMap = @{}
    for ($b = 0; $b -lt $Blocks.Count; $b++) {
        $start = $starts[$b]
        if ($Blocks[$b].Kind -eq 'kv') {
            $headerMap[$start] = New-AerCell 'Item' 'dashTableHeader'
            $headerMap[$start + 1] = New-AerCell 'Count' 'dashTableHeader'
            $headerMap[$start + 2] = New-AerCell '' 'dashTableHeader'
            $headerMap[$start + 3] = New-AerCell '' 'dashTableHeader'
        } else {
            $headerMap[$start] = New-AerCell 'Item' 'dashTableHeader'
            $headerMap[$start + 1] = New-AerCell 'Count' 'dashTableHeader'
            $headerMap[$start + 2] = New-AerCell '%' 'dashTableHeader'
            $headerMap[$start + 3] = New-AerCell 'Bar' 'dashTableHeader'
        }
    }
    $Rows.Add((New-AerDashboardWideRow $headerMap))

    for ($i = 0; $i -lt $Height; $i++) {
        $map = @{}
        for ($b = 0; $b -lt $Blocks.Count; $b++) {
            $start = $starts[$b]
            $data = ConvertTo-AerArray $Blocks[$b].Rows
            $row = if ($i -lt $data.Count) { $data[$i] } else { $null }
            if ($Blocks[$b].Kind -eq 'kv') {
                $map[$start] = New-AerCell (Get-AerValue $row 'Item' '') 'dashTableCell'
                $map[$start + 1] = New-AerCell (Get-AerValue $row 'Count' '') 'dashTableNumber'
                $map[$start + 2] = New-AerCell '' 'dashTableCell'
                $map[$start + 3] = New-AerCell '' 'dashTableCell'
            } else {
                $map[$start] = New-AerCell (Get-AerValue $row 'Item' '') 'dashTableCell'
                $map[$start + 1] = New-AerCell (Get-AerValue $row 'Count' '') 'dashTableNumber'
                $map[$start + 2] = New-AerCell (Get-AerValue $row 'Pct' '') 'dashTablePercent'
                $map[$start + 3] = New-AerCell (Get-AerValue $row 'Bar' '') 'dashBar'
            }
        }
        $Rows.Add((New-AerDashboardWideRow $map))
    }
}

function New-AerDashboardWorkbookSheet {
    param($ReportData)

    $meta = Get-AerValue $ReportData 'metadata'
    $metrics = Get-AerExecutiveMetrics $ReportData
    $inv = Get-AerValue $ReportData 'inventory'
    $vm = Get-AerValue $ReportData 'virtualMachines'
    $vmss = Get-AerValue $ReportData 'virtualMachineScaleSets'
    $db = Get-AerValue $ReportData 'databases'
    $apps = Get-AerValue $ReportData 'applications'
    $adv = Get-AerValue $ReportData 'advisor'
    $sec = Get-AerValue $ReportData 'security'
    $cost = Get-AerValue $ReportData 'cost'
    $diag = Get-AerValue $ReportData 'diagnosticSettings'
    $def = Get-AerValue $ReportData 'defender'
    $errors = ConvertTo-AerArray (Get-AerValue $ReportData 'collectionErrors')
    $rows = [System.Collections.Generic.List[object]]::new()

    $vms = ConvertTo-AerArray (Get-AerValue $vm 'VirtualMachines')
    $scaleSets = ConvertTo-AerArray (Get-AerValue $vmss 'ScaleSets')
    $regions = ConvertTo-AerArray (Get-AerValue $inv 'ByRegion')
    $subs = ConvertTo-AerArray (Get-AerValue $inv 'BySubscription')
    $domains = Get-AerResourceDomainRows -ReportData $ReportData
    $storageAccounts = Get-AerResourceTypeCount -ReportData $ReportData -Predicate { param($type) $type -match 'microsoft\.storage/storageaccounts' }
    $vmTotal = [int](Get-AerValue $vm 'TotalVMs' 0) + [int](Get-AerValue $vmss 'TotalInstances' 0)
    $findings = [int](Get-AerValue $sec 'TotalGaps' 0) + [int](Get-AerValue $cost 'TotalWastedResources' 0)
    $highFindings = [int]((ConvertTo-AerArray (Get-AerValue $sec 'Items') | Where-Object { "$(Get-AerValue $_ 'Severity')" -match 'Critical|High' } | Measure-Object Count -Sum).Sum ?? 0)
    $highFindings += @(ConvertTo-AerArray (Get-AerValue $def 'Recommendations') | Where-Object { "$(Get-AerValue $_ 'RiskLevel')" -match 'Critical|High' }).Count
    $diagPct = Get-AerValue (Get-AerValue $diag 'Summary') 'Percent' $null

    $kpis = @(
        [pscustomobject]@{ Label='Subscriptions'; Value=Get-AerValue $inv 'Subscriptions' 0; Hint='Azure subscriptions in scope' },
        [pscustomobject]@{ Label='Resources'; Value=Get-AerValue $inv 'TotalResources' 0; Hint='Total discovered Azure resources' },
        [pscustomobject]@{ Label='Resource Groups'; Value=Get-AerValue $inv 'TotalResourceGroups' 0; Hint='Distinct resource groups' },
        [pscustomobject]@{ Label='Regions'; Value=$regions.Count; Hint='Azure regions in use' },
        [pscustomobject]@{ Label='Virtual Machines'; Value=$vmTotal; Hint='VM, VMSS and Arc resource signal' },
        [pscustomobject]@{ Label='vCPU'; Value=Get-AerValue $vm 'TotalvCores' 0; Hint='Estimated compute cores' },
        [pscustomobject]@{ Label='Memory GB'; Value=Get-AerValue $vm 'TotalMemoryGB' 0; Hint='Estimated VM memory' },
        [pscustomobject]@{ Label='Disk GB'; Value=Get-AerValue $vm 'TotalDiskGB' 0; Hint='OS and data disk signal' },
        [pscustomobject]@{ Label='Storage Accounts'; Value=$storageAccounts; Hint='Storage account resources' },
        [pscustomobject]@{ Label='Databases'; Value=Get-AerValue $db 'TotalServices' 0; Hint='Database-related services' },
        [pscustomobject]@{ Label='Applications'; Value=Get-AerValue $apps 'TotalServices' 0; Hint='PaaS/application resources' },
        [pscustomobject]@{ Label='Advisor'; Value=Get-AerValue $adv 'TotalRecommendations' 0; Hint='Azure Advisor recommendations' },
        [pscustomobject]@{ Label='High Advisor'; Value=Get-AerValue $adv 'HighImpactCount' 0; Hint='High impact Advisor items' },
        [pscustomobject]@{ Label='Findings'; Value=$findings; Hint='Security and cost findings' },
        [pscustomobject]@{ Label='High Findings'; Value=$highFindings; Hint='Critical and high risk signal' },
        [pscustomobject]@{ Label='Diag Coverage'; Value=$(if ($null -ne $diagPct) { "$diagPct%" } else { 'N/A' }); Hint='Diagnostic settings coverage' }
    )

    $metaLine = "Generated at $(Get-AerValue $meta 'GeneratedAt') | Tenant: $(Get-AerValue $meta 'TenantDomain') | Account: $(Get-AerValue $meta 'Account') | Collection errors: $($errors.Count)"
    $rows.Add((New-AerDashboardWideRow @{ 1 = New-AerCell 'Azure Estate Dashboard' 'dashTitle' } -DefaultStyle 'dashTitle'))
    $rows.Add((New-AerDashboardWideRow @{ 1 = New-AerCell '' 'dashTitle' } -DefaultStyle 'dashTitle'))
    $rows.Add((New-AerDashboardWideRow @{ 1 = New-AerCell $metaLine 'dashMeta' } -DefaultStyle 'dashMeta'))
    $rows.Add((New-AerDashboardWideRow @{ 1 = New-AerCell '' 'dashMeta' } -DefaultStyle 'dashMeta'))
    $rows.Add((New-AerDashboardWideRow @{}))

    $cardStarts = @(1, 5, 9, 13)
    for ($rowGroup = 0; $rowGroup -lt 4; $rowGroup++) {
        $titleMap = @{}
        $valueMap = @{}
        $hintMap = @{}
        for ($colGroup = 0; $colGroup -lt 4; $colGroup++) {
            $idx = ($rowGroup * 4) + $colGroup
            $start = $cardStarts[$colGroup]
            $kpi = $kpis[$idx]
            Set-AerDashboardSpan -Map $titleMap -Start $start -End ($start + 3) -Style 'dashCardTitle' -Value $kpi.Label
            Set-AerDashboardSpan -Map $valueMap -Start $start -End ($start + 3) -Style 'dashCardValue' -Value $kpi.Value
            Set-AerDashboardSpan -Map $hintMap -Start $start -End ($start + 3) -Style 'dashCardHint' -Value $kpi.Hint
        }
        $rows.Add((New-AerDashboardWideRow $titleMap))
        $rows.Add((New-AerDashboardWideRow $valueMap))
        $rows.Add((New-AerDashboardWideRow $hintMap))
        if ($rowGroup -lt 3) { $rows.Add((New-AerDashboardWideRow @{})) }
    }

    $rows.Add((New-AerDashboardWideRow @{ 1 = New-AerCell 'Azure Estate Distribution' 'dashSection' } -DefaultStyle 'dashSection'))
    $rows.Add((New-AerDashboardWideRow @{}))
    $distributionTitleMap = @{}
    Set-AerDashboardSpan -Map $distributionTitleMap -Start 1 -End 4 -Style 'dashTableTitle' -Value 'Resources by Domain'
    Set-AerDashboardSpan -Map $distributionTitleMap -Start 6 -End 9 -Style 'dashTableTitle' -Value 'Resources by Subscription'
    Set-AerDashboardSpan -Map $distributionTitleMap -Start 11 -End 14 -Style 'dashTableTitle' -Value 'Resources by Region'
    $rows.Add((New-AerDashboardWideRow $distributionTitleMap))
    $rows.Add((New-AerDashboardWideRow @{
        1 = New-AerCell 'Item' 'dashTableHeader'; 2 = New-AerCell 'Count' 'dashTableHeader'; 3 = New-AerCell '%' 'dashTableHeader'; 4 = New-AerCell 'Bar' 'dashTableHeader'
        6 = New-AerCell 'Item' 'dashTableHeader'; 7 = New-AerCell 'Count' 'dashTableHeader'; 8 = New-AerCell '%' 'dashTableHeader'; 9 = New-AerCell 'Bar' 'dashTableHeader'
        11 = New-AerCell 'Item' 'dashTableHeader'; 12 = New-AerCell 'Count' 'dashTableHeader'; 13 = New-AerCell '%' 'dashTableHeader'; 14 = New-AerCell 'Bar' 'dashTableHeader'
    }))

    $domainRows = @(New-AerDashboardDistributionRows -Rows $domains -Top 7)
    $subRows = @(New-AerDashboardDistributionRows -Rows $subs -Top 7)
    $regionRows = @(New-AerDashboardDistributionRows -Rows $regions -Top 7)
    for ($i = 0; $i -lt 7; $i++) {
        $d = if ($i -lt $domainRows.Count) { $domainRows[$i] } else { $null }
        $s = if ($i -lt $subRows.Count) { $subRows[$i] } else { $null }
        $r = if ($i -lt $regionRows.Count) { $regionRows[$i] } else { $null }
        $rows.Add((New-AerDashboardWideRow @{
            1 = New-AerCell (Get-AerValue $d 'Item' '') 'dashTableCell'; 2 = New-AerCell (Get-AerValue $d 'Count' '') 'dashTableNumber'; 3 = New-AerCell (Get-AerValue $d 'Pct' '') 'dashTablePercent'; 4 = New-AerCell (Get-AerValue $d 'Bar' '') 'dashBar'
            6 = New-AerCell (Get-AerValue $s 'Item' '') 'dashTableCell'; 7 = New-AerCell (Get-AerValue $s 'Count' '') 'dashTableNumber'; 8 = New-AerCell (Get-AerValue $s 'Pct' '') 'dashTablePercent'; 9 = New-AerCell (Get-AerValue $s 'Bar' '') 'dashBar'
            11 = New-AerCell (Get-AerValue $r 'Item' '') 'dashTableCell'; 12 = New-AerCell (Get-AerValue $r 'Count' '') 'dashTableNumber'; 13 = New-AerCell (Get-AerValue $r 'Pct' '') 'dashTablePercent'; 14 = New-AerCell (Get-AerValue $r 'Bar' '') 'dashBar'
        }))
    }

    $rows.Add((New-AerDashboardWideRow @{}))
    $rows.Add((New-AerDashboardWideRow @{ 1 = New-AerCell 'Compute Dashboard' 'dashSection' } -DefaultStyle 'dashSection'))
    $rows.Add((New-AerDashboardWideRow @{}))

    $runningVms = @($vms | Where-Object { "$(Get-AerValue $_ 'Status')" -match 'running' }).Count
    $deallocatedVms = @($vms | Where-Object { "$(Get-AerValue $_ 'Status')" -match 'deallocated|stopped' }).Count
    $bootEnabled = @($vms | Where-Object { [bool](Get-AerValue $_ 'BootDiagnostics' $false) }).Count
    $publicIpVms = @($vms | Where-Object { -not [string]::IsNullOrWhiteSpace("$(Get-AerValue $_ 'PublicIp')") }).Count
    $computeTotals = New-AerDashboardKvRows @(
        [pscustomobject]@{ Item = 'VM resources'; Count = $vmTotal }
        [pscustomobject]@{ Item = 'Azure VMs'; Count = Get-AerValue $vm 'TotalVMs' 0 }
        [pscustomobject]@{ Item = 'VM Scale Sets'; Count = Get-AerValue $vmss 'TotalVMSS' 0 }
        [pscustomobject]@{ Item = 'VMSS instances'; Count = Get-AerValue $vmss 'TotalInstances' 0 }
        [pscustomobject]@{ Item = 'Total vCPU'; Count = Get-AerValue $vm 'TotalvCores' 0 }
        [pscustomobject]@{ Item = 'Total memory GB'; Count = Get-AerValue $vm 'TotalMemoryGB' 0 }
        [pscustomobject]@{ Item = 'Total disk GB'; Count = Get-AerValue $vm 'TotalDiskGB' 0 }
    )
    $operationalSignals = New-AerDashboardKvRows @(
        [pscustomobject]@{ Item = 'Boot diagnostics enabled'; Count = $bootEnabled }
        [pscustomobject]@{ Item = 'No boot diagnostics'; Count = [math]::Max(0, $vms.Count - $bootEnabled) }
        [pscustomobject]@{ Item = 'Public IP attached'; Count = $publicIpVms }
        [pscustomobject]@{ Item = 'Running VMs'; Count = $runningVms }
        [pscustomobject]@{ Item = 'Stopped/deallocated VMs'; Count = $deallocatedVms }
    )
    $vmssModeRows = @(Group-AerDashboardSumRows -Items $scaleSets -Key 'OrchestrationMode' -SumKey 'Capacity' -Top 7)

    Add-AerDashboardThreeBlocks -Rows $rows -Height 7 -Blocks @(
        [pscustomobject]@{ Title = 'Compute Totals'; Kind = 'kv'; Rows = $computeTotals }
        [pscustomobject]@{ Title = 'VMs by OS'; Kind = 'dist'; Rows = @(New-AerDashboardDistributionRows -Rows (Group-AerDashboardCountRows -Items $vms -Key 'Os' -Top 7) -Top 7) }
        [pscustomobject]@{ Title = 'VMs by SKU'; Kind = 'dist'; Rows = @(New-AerDashboardDistributionRows -Rows (Group-AerDashboardCountRows -Items $vms -Key 'Sku' -Top 7) -Top 7) }
    )
    $rows.Add((New-AerDashboardWideRow @{}))
    $rows.Add((New-AerDashboardWideRow @{}))
    Add-AerDashboardThreeBlocks -Rows $rows -Height 7 -Blocks @(
        [pscustomobject]@{ Title = 'VMs by Image'; Kind = 'dist'; Rows = @(New-AerDashboardDistributionRows -Rows (Group-AerDashboardCountRows -Items $vms -Key 'Image' -Top 7) -Top 7) }
        [pscustomobject]@{ Title = 'VMSS Mode'; Kind = 'dist'; Rows = @(New-AerDashboardDistributionRows -Rows $vmssModeRows -Top 7) }
        [pscustomobject]@{ Title = 'Operational Signals'; Kind = 'kv'; Rows = $operationalSignals }
    )

    $rowHeights = @(30, 26, 22, 22, 12, 18, 20, 22, 12, 18, 20, 22, 12, 18, 20, 22, 12, 18, 20, 22, 12, 18, 20, 18, 18, 18, 18, 18, 18, 18)
    while ($rowHeights.Count -lt $rows.Count) { $rowHeights += 18 }

    [pscustomobject]@{
        Name       = 'Dashboard'
        Rows       = $rows
        Merges     = @()
        AutoFilter = $null
        FreezeRow  = 0
        RowHeights = $rowHeights
        ColWidths  = @(24, 12, 10, 26, 3, 28, 12, 10, 26, 3, 28, 12, 10, 26, 3, 2)
    }
}

function New-AerWorkbookSheets {
    param($ReportData)

    $inv = Get-AerValue $ReportData 'inventory'
    $sec = Get-AerValue $ReportData 'security'
    $cost = Get-AerValue $ReportData 'cost'
    $adv = Get-AerValue $ReportData 'advisor'
    $vm = Get-AerValue $ReportData 'virtualMachines'
    $db = Get-AerValue $ReportData 'relationalDatabases'
    $dataServices = Get-AerValue $ReportData 'dataServices'
    $appServices = Get-AerValue $ReportData 'applicationServices'
    $pol = Get-AerValue $ReportData 'policy'
    $def = Get-AerValue $ReportData 'defender'
    $errors = ConvertTo-AerArray (Get-AerValue $ReportData 'collectionErrors')

    $sheets = [System.Collections.Generic.List[object]]::new()
    $sheets.Add((New-AerDashboardWorkbookSheet -ReportData $ReportData))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Executive Summary' -Title 'Executive Summary' -Subtitle 'Business-readable metrics and recommended action areas.' -Columns @(
        [pscustomobject]@{ Header = 'Metric'; Width = 28; Key = 'Metric' },
        [pscustomobject]@{ Header = 'Value'; Width = 16; Key = 'Value' },
        [pscustomobject]@{ Header = 'Signal'; Width = 28; Key = 'Signal' }
    ) -Items (Get-AerExecutiveMetrics $ReportData)))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Executive Signals' -Title 'Executive Signals' -Subtitle 'Prioritized signals for leadership and action owners.' -Columns @(
        [pscustomobject]@{ Header = 'Area'; Width = 20; Key = 'Area' },
        [pscustomobject]@{ Header = 'Signal'; Width = 30; Key = 'Signal' },
        [pscustomobject]@{ Header = 'Status'; Width = 18; Key = 'Status' },
        [pscustomobject]@{ Header = 'Recommended Action'; Width = 54; Key = 'Action' }
    ) -Items (Get-AerExecutiveSignals $ReportData)))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Technical Inventory' -Title 'Technical Inventory' -Subtitle 'Raw Azure Resource Graph inventory with resource identifiers.' -Columns @(
        [pscustomobject]@{ Header = 'Subscription'; Width = 30; Expression = { param($r) Get-AerSubscriptionName -ReportData $ReportData -SubscriptionId (Get-AerFirstValue $r @('subscriptionId', 'SubscriptionId')) } },
        [pscustomobject]@{ Header = 'Resource Group'; Width = 26; Expression = { param($r) Get-AerFirstValue $r @('resourceGroup', 'ResourceGroup') } },
        [pscustomobject]@{ Header = 'Name'; Width = 34; Expression = { param($r) Get-AerFirstValue $r @('name', 'Name') } },
        [pscustomobject]@{ Header = 'Type'; Width = 40; Expression = { param($r) Get-AerFirstValue $r @('type', 'Type') } },
        [pscustomobject]@{ Header = 'Region'; Width = 18; Expression = { param($r) Get-AerFirstValue $r @('location', 'Location') } },
        [pscustomobject]@{ Header = 'State'; Width = 18; Expression = { param($r) Get-AerFirstValue $r @('provisioningState', 'ProvisioningState', 'status', 'Status') } },
        [pscustomobject]@{ Header = 'Tags'; Width = 44; Expression = { param($r) Format-AerExportValue (Get-AerFirstValue $r @('tags', 'Tags')) } },
        [pscustomobject]@{ Header = 'Resource ID'; Width = 80; Expression = { param($r) Get-AerFirstValue $r @('id', 'Id') } }
    ) -Items (ConvertTo-AerArray (Get-AerValue $inv 'ResourceList'))))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Security Findings' -Title 'Security Findings' -Subtitle 'General security gaps with affected resource samples.' -Columns @(
        [pscustomobject]@{ Header = 'Severity'; Width = 14; Key = 'Severity' },
        [pscustomobject]@{ Header = 'Finding'; Width = 48; Key = 'Title' },
        [pscustomobject]@{ Header = 'Affected Type'; Width = 34; Expression = { param($r) Get-AerFindingAffectedType $r } },
        [pscustomobject]@{ Header = 'Affected Resources'; Width = 18; Key = 'Count' },
        [pscustomobject]@{ Header = 'Resource Samples'; Width = 80; Expression = { param($r) Limit-AerText (Format-AerExportValue (Get-AerValue $r 'Resources')) 220 } }
    ) -Items (ConvertTo-AerArray (Get-AerValue $sec 'Items'))))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Cost Findings' -Title 'Cost Findings' -Subtitle 'Cost waste opportunities and impacted resources.' -Columns @(
        [pscustomobject]@{ Header = 'Severity'; Width = 14; Key = 'Severity' },
        [pscustomobject]@{ Header = 'Finding'; Width = 48; Key = 'Title' },
        [pscustomobject]@{ Header = 'Affected Type'; Width = 34; Expression = { param($r) Get-AerFindingAffectedType $r } },
        [pscustomobject]@{ Header = 'Affected Resources'; Width = 18; Key = 'Count' },
        [pscustomobject]@{ Header = 'Resource Samples'; Width = 80; Expression = { param($r) Limit-AerText (Format-AerExportValue (Get-AerValue $r 'Resources')) 220 } }
    ) -Items (ConvertTo-AerArray (Get-AerValue $cost 'Items'))))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Advisor' -Title 'Azure Advisor' -Subtitle 'Advisor recommendations by category, impact and target resource.' -Columns @(
        [pscustomobject]@{ Header = 'Category'; Width = 20; Key = 'Category' },
        [pscustomobject]@{ Header = 'Impact'; Width = 14; Key = 'Impact' },
        [pscustomobject]@{ Header = 'Recommendation'; Width = 60; Expression = { param($r) Get-AerAdvisorRecommendationText $r } },
        [pscustomobject]@{ Header = 'Resource'; Width = 34; Expression = { param($r) Get-AerAdvisorResourceName $r } },
        [pscustomobject]@{ Header = 'Resource Type'; Width = 34; Key = 'ResourceType' },
        [pscustomobject]@{ Header = 'Subscription'; Width = 28; Expression = { param($r) Get-AerAdvisorSubscriptionName -ReportData $ReportData -Recommendation $r } },
        [pscustomobject]@{ Header = 'Resource Group'; Width = 26; Expression = { param($r) Get-AerAdvisorResourceGroup $r } },
        [pscustomobject]@{ Header = 'Resource ID'; Width = 78; Key = 'ResourceId' }
    ) -Items (ConvertTo-AerArray (Get-AerValue $adv 'Recommendations'))))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Compute' -Title 'Compute' -Subtitle 'Virtual machine inventory with sizing and operational state.' -Columns @(
        [pscustomobject]@{ Header = 'Subscription'; Width = 30; Key = 'SubscriptionName' },
        [pscustomobject]@{ Header = 'Resource Group'; Width = 24; Key = 'ResourceGroup' },
        [pscustomobject]@{ Header = 'Name'; Width = 30; Key = 'Name' },
        [pscustomobject]@{ Header = 'OS'; Width = 12; Key = 'Os' },
        [pscustomobject]@{ Header = 'Region'; Width = 16; Key = 'Location' },
        [pscustomobject]@{ Header = 'SKU'; Width = 22; Key = 'Sku' },
        [pscustomobject]@{ Header = 'Status'; Width = 16; Key = 'Status' },
        [pscustomobject]@{ Header = 'vCores'; Width = 12; Key = 'VCores' },
        [pscustomobject]@{ Header = 'Memory GB'; Width = 14; Key = 'MemoryGB' },
        [pscustomobject]@{ Header = 'Disk GB'; Width = 14; Key = 'DiskGB' },
        [pscustomobject]@{ Header = 'Public IP'; Width = 18; Key = 'PublicIp' },
        [pscustomobject]@{ Header = 'Resource ID'; Width = 80; Key = 'Id' }
    ) -Items (ConvertTo-AerArray (Get-AerValue $vm 'VirtualMachines'))))

    $dataRows = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (ConvertTo-AerArray (Get-AerValue $db 'Services'))) {
        $dataRows.Add([pscustomobject]@{
            Family = 'Relational'; Type = Get-AerFirstValue $r @('Type'); Name = Get-AerFirstValue $r @('Name')
            SubscriptionName = Get-AerFirstValue $r @('SubscriptionName'); ResourceGroup = Get-AerFirstValue $r @('ResourceGroup')
            Location = Get-AerFirstValue $r @('Location'); Status = Get-AerFirstValue $r @('Status'); Details = Format-AerExportValue $r; Id = Get-AerFirstValue $r @('Id')
        })
    }
    foreach ($r in (Get-AerServiceRows -Container $dataServices)) { $dataRows.Add($r) }
    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Data Services' -Title 'Data Services' -Subtitle 'Relational, NoSQL, cache, analytics and storage services.' -Columns @(
        [pscustomobject]@{ Header = 'Family'; Width = 18; Key = 'Family' },
        [pscustomobject]@{ Header = 'Type'; Width = 32; Key = 'Type' },
        [pscustomobject]@{ Header = 'Name'; Width = 32; Key = 'Name' },
        [pscustomobject]@{ Header = 'Subscription'; Width = 30; Key = 'SubscriptionName' },
        [pscustomobject]@{ Header = 'Resource Group'; Width = 24; Key = 'ResourceGroup' },
        [pscustomobject]@{ Header = 'Region'; Width = 16; Key = 'Location' },
        [pscustomobject]@{ Header = 'Status'; Width = 16; Key = 'Status' },
        [pscustomobject]@{ Header = 'Details'; Width = 80; Key = 'Details' },
        [pscustomobject]@{ Header = 'Resource ID'; Width = 80; Key = 'Id' }
    ) -Items @($dataRows)))

    $appRows = Get-AerServiceRows -Container $appServices
    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Application Services' -Title 'Application Services' -Subtitle 'Web, function, container, integration and AKS services.' -Columns @(
        [pscustomobject]@{ Header = 'Family'; Width = 18; Key = 'Family' },
        [pscustomobject]@{ Header = 'Type'; Width = 32; Key = 'Type' },
        [pscustomobject]@{ Header = 'Name'; Width = 32; Key = 'Name' },
        [pscustomobject]@{ Header = 'Subscription'; Width = 30; Key = 'SubscriptionName' },
        [pscustomobject]@{ Header = 'Resource Group'; Width = 24; Key = 'ResourceGroup' },
        [pscustomobject]@{ Header = 'Region'; Width = 16; Key = 'Location' },
        [pscustomobject]@{ Header = 'Status'; Width = 16; Key = 'Status' },
        [pscustomobject]@{ Header = 'Details'; Width = 80; Key = 'Details' },
        [pscustomobject]@{ Header = 'Resource ID'; Width = 80; Key = 'Id' }
    ) -Items @($appRows)))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Policy' -Title 'Policy' -Subtitle 'Policy assignments, compliance and remediation context.' -Columns @(
        [pscustomobject]@{ Header = 'Name'; Width = 38; Key = 'Name' },
        [pscustomobject]@{ Header = 'Type'; Width = 16; Key = 'Type' },
        [pscustomobject]@{ Header = 'Compliance %'; Width = 16; Key = 'CompliancePercent' },
        [pscustomobject]@{ Header = 'Compliant'; Width = 14; Key = 'CompliantCount' },
        [pscustomobject]@{ Header = 'Non-compliant'; Width = 16; Key = 'NonCompliantCount' },
        [pscustomobject]@{ Header = 'Definition'; Width = 46; Key = 'Definition' },
        [pscustomobject]@{ Header = 'Scope'; Width = 70; Key = 'Scope' },
        [pscustomobject]@{ Header = 'Enforcement'; Width = 18; Key = 'EnforcementMode' }
    ) -Items (ConvertTo-AerArray (Get-AerValue $pol 'Items'))))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Defender' -Title 'Defender for Cloud' -Subtitle 'Security posture recommendations and unhealthy assessments.' -Columns @(
        [pscustomobject]@{ Header = 'Risk'; Width = 16; Key = 'RiskLevel' },
        [pscustomobject]@{ Header = 'Status'; Width = 18; Key = 'Status' },
        [pscustomobject]@{ Header = 'Recommendation'; Width = 58; Key = 'DisplayName' },
        [pscustomobject]@{ Header = 'Resource'; Width = 32; Key = 'ResourceName' },
        [pscustomobject]@{ Header = 'Type'; Width = 34; Key = 'ResourceType' },
        [pscustomobject]@{ Header = 'Subscription'; Width = 30; Key = 'SubscriptionName' },
        [pscustomobject]@{ Header = 'Remediation'; Width = 74; Key = 'Remediation' },
        [pscustomobject]@{ Header = 'Resource ID'; Width = 80; Key = 'Id' }
    ) -Items (ConvertTo-AerArray (Get-AerValue $def 'Recommendations'))))

    $sheets.Add((New-AerSimpleWorkbookSheet -Name 'Collection Errors' -Title 'Collection Errors' -Subtitle 'Collector failures captured during report generation.' -Columns @(
        [pscustomobject]@{ Header = 'Collector'; Width = 24; Key = 'Collector' },
        [pscustomobject]@{ Header = 'Message'; Width = 80; Key = 'Message' },
        [pscustomobject]@{ Header = 'Stack Trace'; Width = 90; Key = 'StackTrace' }
    ) -Items $errors))

    return @($sheets)
}

function Get-AerXlsxStylesXml {
    @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <numFmts count="2">
    <numFmt numFmtId="164" formatCode="#,##0"/>
    <numFmt numFmtId="165" formatCode="0%"/>
  </numFmts>
  <fonts count="17">
    <font><sz val="11"/><color rgb="FF1E293B"/><name val="Calibri"/></font>
    <font><b/><sz val="22"/><color rgb="FFFFFFFF"/><name val="Segoe UI"/></font>
    <font><sz val="10"/><color rgb="FF94A3B8"/><name val="Segoe UI"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Segoe UI"/></font>
    <font><b/><sz val="11"/><color rgb="FF0EA5E9"/><name val="Segoe UI"/></font>
    <font><b/><sz val="11"/><color rgb="FF15803D"/><name val="Segoe UI"/></font>
    <font><b/><sz val="11"/><color rgb="FFB45309"/><name val="Segoe UI"/></font>
    <font><b/><sz val="11"/><color rgb="FFB91C1C"/><name val="Segoe UI"/></font>
    <font><sz val="11"/><color rgb="FF1E293B"/><name val="Segoe UI"/></font>
    <font><b/><sz val="24"/><color rgb="FF38BDF8"/><name val="Segoe UI"/></font>
    <font><b/><sz val="12"/><color rgb="FF001F3F"/><name val="Aptos"/></font>
    <font><sz val="9"/><color rgb="FF365B8A"/><name val="Aptos"/></font>
    <font><b/><sz val="10"/><color rgb="FF001F3F"/><name val="Aptos"/></font>
    <font><b/><sz val="10"/><color rgb="FF001F3F"/><name val="Aptos"/></font>
    <font><b/><sz val="11"/><color rgb="FF0047FF"/><name val="Aptos"/></font>
    <font><b/><sz val="10"/><color rgb="FF2563EB"/><name val="Aptos"/></font>
    <font><b/><sz val="10"/><color rgb="FF000000"/><name val="Aptos"/></font>
  </fonts>
  <fills count="15">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF0A0F1E"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF162033"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1E293B"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF0EA5E9"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFDCFCE7"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFFEF3C7"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFFEE2E2"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF6366F1"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFC"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFEAF2FB"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFDCE5F1"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFFFFFFF"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFD9EAFB"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
      <left style="thin"><color rgb="FFE2E8F0"/></left>
      <right style="thin"><color rgb="FFE2E8F0"/></right>
      <top style="thin"><color rgb="FFE2E8F0"/></top>
      <bottom style="thin"><color rgb="FFE2E8F0"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="28">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="3" fillId="5" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="164" fontId="9" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center" wrapText="1"/></xf>
    <xf numFmtId="0" fontId="8" fillId="10" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
    <xf numFmtId="164" fontId="8" fillId="10" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="top"/></xf>
    <xf numFmtId="0" fontId="5" fillId="6" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="6" fillId="7" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="7" fillId="8" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="165" fontId="8" fillId="10" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="top"/></xf>
    <xf numFmtId="0" fontId="10" fillId="11" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="11" fillId="11" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="12" fillId="12" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="13" fillId="13" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="164" fontId="14" fillId="13" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="11" fillId="13" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="12" fillId="14" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="16" fillId="13" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="0" fontId="8" fillId="13" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
    <xf numFmtId="164" fontId="8" fillId="13" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
    <xf numFmtId="0" fontId="8" fillId="13" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
    <xf numFmtId="0" fontId="15" fillId="13" borderId="1" xfId="0" applyFill="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
  <dxfs count="0"/>
  <tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleMedium9"/>
</styleSheet>
'@
}

function ConvertTo-AerWorksheetXml {
    param($Sheet)

    $styleMap = @{
        default = 0; title = 1; subtitle = 2; section = 3; kpiLabel = 4; kpiValue = 5; header = 6; cell = 7
        number = 8; good = 9; warn = 10; bad = 11; muted = 12; accent = 13; card = 14; percent = 15
        dashTitle = 16; dashMeta = 17; dashSection = 18; dashCardTitle = 19; dashCardValue = 20; dashCardHint = 21
        dashTableTitle = 22; dashTableHeader = 23; dashTableCell = 24; dashTableNumber = 25; dashTablePercent = 26; dashBar = 27
    }
    $rows = @($Sheet.Rows)
    $maxCols = 1
    foreach ($row in $rows) { if (@($row).Count -gt $maxCols) { $maxCols = @($row).Count } }
    $lastCell = (ConvertTo-AerColumnLetter $maxCols) + [math]::Max(1, $rows.Count)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.AppendLine('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    [void]$sb.AppendLine("  <dimension ref=`"A1:$lastCell`"/>")
    if ($Sheet.FreezeRow -and $Sheet.FreezeRow -gt 0) {
        $topLeft = "A$($Sheet.FreezeRow + 1)"
        [void]$sb.AppendLine("  <sheetViews><sheetView workbookViewId=`"0`"><pane ySplit=`"$($Sheet.FreezeRow)`" topLeftCell=`"$topLeft`" activePane=`"bottomLeft`" state=`"frozen`"/></sheetView></sheetViews>")
    } else {
        [void]$sb.AppendLine('  <sheetViews><sheetView workbookViewId="0"/></sheetViews>')
    }
    [void]$sb.AppendLine('  <sheetFormatPr defaultRowHeight="18"/>')

    $widths = @($Sheet.ColWidths)
    if ($widths.Count -gt 0) {
        [void]$sb.AppendLine('  <cols>')
        for ($i = 0; $i -lt $widths.Count; $i++) {
            $w = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.##}', [double]$widths[$i])
            [void]$sb.AppendLine("    <col min=`"$($i + 1)`" max=`"$($i + 1)`" width=`"$w`" customWidth=`"1`"/>")
        }
        [void]$sb.AppendLine('  </cols>')
    }

    [void]$sb.AppendLine('  <sheetData>')
    $rowHeights = @($Sheet.RowHeights)
    for ($r = 0; $r -lt $rows.Count; $r++) {
        $row = @($rows[$r])
        $rowNum = $r + 1
        $height = if ($r -lt $rowHeights.Count -and $rowHeights[$r]) { [double]$rowHeights[$r] } elseif ($rowNum -eq 1) { 32 } elseif ($rowNum -eq 2) { 22 } elseif ($rowNum -eq 6) { 34 } else { 20 }
        [void]$sb.AppendLine("    <row r=`"$rowNum`" ht=`"$height`" customHeight=`"1`">")
        for ($c = 0; $c -lt $row.Count; $c++) {
            $cell = $row[$c]
            if ($null -eq $cell) { continue }
            if (-not $cell.PSObject.Properties['Value']) { $cell = New-AerCell $cell 'cell' }
            $ref = "$(ConvertTo-AerColumnLetter ($c + 1))$rowNum"
            $styleName = if ($cell.Style) { $cell.Style } else { 'cell' }
            $styleId = if ($styleMap.ContainsKey($styleName)) { $styleMap[$styleName] } else { 7 }
            $value = $cell.Value
            if ($null -eq $value -or "$value" -eq '') {
                [void]$sb.AppendLine("      <c r=`"$ref`" s=`"$styleId`"/>")
            } elseif ($value -is [byte] -or $value -is [int16] -or $value -is [int32] -or $value -is [int64] -or
                $value -is [decimal] -or $value -is [double] -or $value -is [single]) {
                $num = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $value)
                [void]$sb.AppendLine("      <c r=`"$ref`" s=`"$styleId`"><v>$num</v></c>")
            } else {
                $text = ConvertTo-AerXmlText $value
                [void]$sb.AppendLine("      <c r=`"$ref`" s=`"$styleId`" t=`"inlineStr`"><is><t>$text</t></is></c>")
            }
        }
        [void]$sb.AppendLine('    </row>')
    }
    [void]$sb.AppendLine('  </sheetData>')

    if ($Sheet.AutoFilter) {
        [void]$sb.AppendLine("  <autoFilter ref=`"$($Sheet.AutoFilter)`"/>")
    }
    $merges = ConvertTo-AerArray $Sheet.Merges
    if ($merges.Count -gt 0) {
        [void]$sb.AppendLine("  <mergeCells count=`"$($merges.Count)`">")
        foreach ($merge in $merges) { [void]$sb.AppendLine("    <mergeCell ref=`"$merge`"/>") }
        [void]$sb.AppendLine('  </mergeCells>')
    }

    [void]$sb.AppendLine('</worksheet>')
    return $sb.ToString()
}

function Add-AerZipEntry {
    param(
        [System.IO.Compression.ZipArchive] $Zip,
        [string] $Name,
        [string] $Content
    )

    $entry = $Zip.CreateEntry($Name, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
    try { $writer.Write($Content) }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function New-AerExcelReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $ReportData,
        [Parameter(Mandatory)] [string] $Path
    )

    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

    $sheets = @(New-AerWorkbookSheets -ReportData $ReportData)
    $dir = Split-Path -Parent $Path
    if ($dir) { $null = New-Item -ItemType Directory -Force -Path $dir }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        $sheetOverrides = for ($i = 1; $i -le $sheets.Count; $i++) {
            "<Override PartName=`"/xl/worksheets/sheet$i.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml`"/>"
        }
        Add-AerZipEntry $zip '[Content_Types].xml' @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  $($sheetOverrides -join "`n  ")
</Types>
"@
        Add-AerZipEntry $zip '_rels/.rels' @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@
        $created = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        Add-AerZipEntry $zip 'docProps/core.xml' @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Azure Estate Report</dc:title>
  <dc:creator>AER</dc:creator>
  <cp:lastModifiedBy>AER</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$created</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$created</dcterms:modified>
</cp:coreProperties>
"@
        $titlesOfParts = for ($i = 0; $i -lt $sheets.Count; $i++) {
            '<vt:lpstr>' + (ConvertTo-AerXmlText $sheets[$i].Name) + '</vt:lpstr>'
        }
        $titlesOfPartsXml = $titlesOfParts -join ''
        Add-AerZipEntry $zip 'docProps/app.xml' @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>AER</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>$($sheets.Count)</vt:i4></vt:variant></vt:vector></HeadingPairs>
  <TitlesOfParts><vt:vector size="$($sheets.Count)" baseType="lpstr">$titlesOfPartsXml</vt:vector></TitlesOfParts>
</Properties>
"@
        $sheetXml = for ($i = 0; $i -lt $sheets.Count; $i++) {
            "<sheet name=`"$(ConvertTo-AerXmlText $sheets[$i].Name)`" sheetId=`"$($i + 1)`" r:id=`"rId$($i + 1)`"/>"
        }
        Add-AerZipEntry $zip 'xl/workbook.xml' @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <bookViews><workbookView activeTab="0"/></bookViews>
  <sheets>
    $($sheetXml -join "`n    ")
  </sheets>
</workbook>
"@
        $rels = for ($i = 1; $i -le $sheets.Count; $i++) {
            "<Relationship Id=`"rId$i`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet`" Target=`"worksheets/sheet$i.xml`"/>"
        }
        Add-AerZipEntry $zip 'xl/_rels/workbook.xml.rels' @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  $($rels -join "`n  ")
  <Relationship Id="rId$($sheets.Count + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@
        Add-AerZipEntry $zip 'xl/styles.xml' (Get-AerXlsxStylesXml)
        for ($i = 0; $i -lt $sheets.Count; $i++) {
            Add-AerZipEntry $zip "xl/worksheets/sheet$($i + 1).xml" (ConvertTo-AerWorksheetXml -Sheet $sheets[$i])
        }
    }
    finally {
        $zip.Dispose()
        $fs.Dispose()
    }

    return $Path
}

function ConvertTo-AerPdfText {
    param($Value)

    $text = "$(Format-AerExportValue $Value)"
    $normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $normalized.ToCharArray()) {
        $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -eq [Globalization.UnicodeCategory]::NonSpacingMark) { continue }
        $code = [int][char]$ch
        if ($code -ge 32 -and $code -le 126) { [void]$sb.Append($ch) }
        elseif ($code -eq 8211 -or $code -eq 8212) { [void]$sb.Append('-') }
        elseif ($code -eq 8230) { [void]$sb.Append('...') }
        else { [void]$sb.Append('?') }
    }
    return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function Escape-AerPdfString {
    param($Value)

    return (ConvertTo-AerPdfText $Value).Replace('\', '\\').Replace('(', '\(').Replace(')', '\)')
}

function ConvertTo-AerPdfNumber {
    param([double] $Value)
    [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $Value)
}

function ConvertTo-AerRgbParts {
    param([string] $Hex)

    $h = $Hex.TrimStart('#')
    if ($h.Length -ne 6) { $h = '000000' }
    @(
        [Convert]::ToInt32($h.Substring(0, 2), 16) / 255
        [Convert]::ToInt32($h.Substring(2, 2), 16) / 255
        [Convert]::ToInt32($h.Substring(4, 2), 16) / 255
    )
}

function Add-AerPdfText {
    param(
        [System.Collections.Generic.List[string]] $Ops,
        [double] $X,
        [double] $Y,
        $Text,
        [double] $Size = 10,
        [string] $Font = 'F1',
        [string] $Color = '#1E293B',
        [int] $MaxChars = 120
    )

    $safe = ConvertTo-AerPdfText $Text
    if ($safe.Length -gt $MaxChars) { $safe = $safe.Substring(0, [math]::Max(0, $MaxChars - 1)) + '...' }
    $escaped = Escape-AerPdfString $safe
    $rgb = ConvertTo-AerRgbParts $Color
    $Ops.Add(("{0} {1} {2} rg BT /{3} {4} Tf {5} {6} Td ({7}) Tj ET" -f
        (ConvertTo-AerPdfNumber $rgb[0]), (ConvertTo-AerPdfNumber $rgb[1]), (ConvertTo-AerPdfNumber $rgb[2]),
        $Font, (ConvertTo-AerPdfNumber $Size), (ConvertTo-AerPdfNumber $X), (ConvertTo-AerPdfNumber $Y), $escaped))
}

function Add-AerPdfRect {
    param(
        [System.Collections.Generic.List[string]] $Ops,
        [double] $X,
        [double] $Y,
        [double] $W,
        [double] $H,
        [string] $Fill = '#FFFFFF'
    )

    $rgb = ConvertTo-AerRgbParts $Fill
    $Ops.Add(("{0} {1} {2} rg {3} {4} {5} {6} re f" -f
        (ConvertTo-AerPdfNumber $rgb[0]), (ConvertTo-AerPdfNumber $rgb[1]), (ConvertTo-AerPdfNumber $rgb[2]),
        (ConvertTo-AerPdfNumber $X), (ConvertTo-AerPdfNumber $Y), (ConvertTo-AerPdfNumber $W), (ConvertTo-AerPdfNumber $H)))
}

function Add-AerPdfLine {
    param(
        [System.Collections.Generic.List[string]] $Ops,
        [double] $X1,
        [double] $Y1,
        [double] $X2,
        [double] $Y2,
        [string] $Color = '#CBD5E1',
        [double] $Width = 0.5
    )

    $rgb = ConvertTo-AerRgbParts $Color
    $Ops.Add(("{0} {1} {2} RG {3} w {4} {5} m {6} {7} l S" -f
        (ConvertTo-AerPdfNumber $rgb[0]), (ConvertTo-AerPdfNumber $rgb[1]), (ConvertTo-AerPdfNumber $rgb[2]),
        (ConvertTo-AerPdfNumber $Width), (ConvertTo-AerPdfNumber $X1), (ConvertTo-AerPdfNumber $Y1),
        (ConvertTo-AerPdfNumber $X2), (ConvertTo-AerPdfNumber $Y2)))
}

function New-AerPdfPage {
    param([scriptblock] $Build)

    $ops = [System.Collections.Generic.List[string]]::new()
    & $Build $ops
    return ($ops -join "`n")
}

function Add-AerPdfPageHeader {
    param(
        [System.Collections.Generic.List[string]] $Ops,
        [string] $Title,
        [string] $Subtitle
    )

    Add-AerPdfRect $Ops 0 548 842 47 '#0F172A'
    Add-AerPdfRect $Ops 0 544 842 4 '#0EA5E9'
    Add-AerPdfText $Ops 36 570 $Title 16 'F2' '#FFFFFF' 90
    Add-AerPdfText $Ops 36 555 $Subtitle 8.5 'F1' '#CBD5E1' 140
}

function Add-AerPdfTable {
    param(
        [System.Collections.Generic.List[string]] $Ops,
        [double] $X,
        [double] $Y,
        [object[]] $Columns,
        [object[]] $Rows,
        [int] $MaxRows = 22
    )

    $rowH = 17
    $headerH = 21
    $xCursor = $X
    Add-AerPdfRect $Ops $X ($Y - $headerH + 4) (@($Columns | Measure-Object Width -Sum).Sum) $headerH '#1E293B'
    foreach ($col in $Columns) {
        Add-AerPdfText $Ops ($xCursor + 5) ($Y - 10) $col.Header 8 'F2' '#FFFFFF' ([int]($col.Width / 4))
        $xCursor += [double]$col.Width
    }

    $yCursor = $Y - $headerH + 4
    $shown = @($Rows | Select-Object -First $MaxRows)
    for ($i = 0; $i -lt $shown.Count; $i++) {
        $row = $shown[$i]
        $yCursor -= $rowH
        Add-AerPdfRect $Ops $X $yCursor (@($Columns | Measure-Object Width -Sum).Sum) $rowH $(if ($i % 2 -eq 0) { '#FFFFFF' } else { '#F8FAFC' })
        Add-AerPdfLine $Ops $X $yCursor ($X + (@($Columns | Measure-Object Width -Sum).Sum)) $yCursor '#E2E8F0' 0.35
        $xCursor = $X
        foreach ($col in $Columns) {
            $value = if ($col.PSObject.Properties['Expression']) { & $col.Expression $row } else { Get-AerValue $row $col.Key }
            Add-AerPdfText $Ops ($xCursor + 5) ($yCursor + 5) $value 7.5 'F1' '#1E293B' ([math]::Max(8, [int]($col.Width / 4.2)))
            $xCursor += [double]$col.Width
        }
    }
}

function New-AerPdfTablePages {
    param(
        [string] $Title,
        [string] $Subtitle,
        [object[]] $Columns,
        [object[]] $Rows,
        [int] $RowsPerPage = 24,
        [int] $MaxRows = 1000
    )

    $pages = [System.Collections.Generic.List[string]]::new()
    $data = @(ConvertTo-AerArray $Rows | Select-Object -First $MaxRows)
    if ($data.Count -eq 0) { $data = @([pscustomobject]@{}) }
    $chunks = [math]::Max(1, [math]::Ceiling($data.Count / $RowsPerPage))
    for ($p = 0; $p -lt $chunks; $p++) {
        $start = $p * $RowsPerPage
        $slice = @($data | Select-Object -Skip $start -First $RowsPerPage)
        $pageNo = $p + 1
        $pages.Add((New-AerPdfPage {
            param($ops)
            Add-AerPdfRect $ops 0 0 842 595 '#F8FAFC'
            Add-AerPdfPageHeader $ops $Title ("$Subtitle · page $pageNo of $chunks")
            Add-AerPdfTable $ops 36 515 $Columns $slice $RowsPerPage
            Add-AerPdfText $ops 36 22 "AER export · Rows $($start + 1)-$($start + $slice.Count) of $($data.Count)" 8 'F1' '#64748B' 120
        }))
    }
    return @($pages)
}

function Add-AerPdfPageSet {
    param(
        [System.Collections.Generic.List[string]] $Pages,
        $PageSet
    )

    foreach ($page in @($PageSet)) {
        $Pages.Add([string]$page)
    }
}

function New-AerPdfReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $ReportData,
        [Parameter(Mandatory)] [string] $Path
    )

    $dir = Split-Path -Parent $Path
    if ($dir) { $null = New-Item -ItemType Directory -Force -Path $dir }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }

    $meta = Get-AerValue $ReportData 'metadata'
    $inv = Get-AerValue $ReportData 'inventory'
    $metrics = Get-AerExecutiveMetrics $ReportData
    $signals = Get-AerExecutiveSignals $ReportData
    $errors = ConvertTo-AerArray (Get-AerValue $ReportData 'collectionErrors')
    $pages = [System.Collections.Generic.List[string]]::new()

    $pages.Add((New-AerPdfPage {
        param($ops)
        Add-AerPdfRect $ops 0 0 842 595 '#0A0F1E'
        Add-AerPdfRect $ops 0 548 842 47 '#0F172A'
        Add-AerPdfRect $ops 0 544 842 4 '#0EA5E9'
        Add-AerPdfText $ops 36 570 'Azure Estate Report' 18 'F2' '#FFFFFF' 80
        Add-AerPdfText $ops 36 555 ("Generated {0} · Tenant {1}" -f (Get-AerValue $meta 'GeneratedAt'), (Get-AerValue $meta 'TenantDomain')) 8.5 'F1' '#CBD5E1' 130

        $cards = @($metrics | Where-Object Metric -in @('Subscriptions', 'Resources', 'Virtual machines', 'Advisor recommendations', 'Cost findings', 'Collection errors'))
        $x = 36; $y = 470; $w = 122; $h = 58
        for ($i = 0; $i -lt $cards.Count; $i++) {
            $card = $cards[$i]
            $cx = $x + (($i % 3) * 138)
            $cy = $y - ([math]::Floor($i / 3) * 78)
            Add-AerPdfRect $ops $cx $cy $w $h '#162033'
            Add-AerPdfRect $ops $cx ($cy + $h - 4) $w 4 $(if ($card.Metric -eq 'Collection errors' -and [int]$card.Value -gt 0) { '#F59E0B' } else { '#0EA5E9' })
            Add-AerPdfText $ops ($cx + 10) ($cy + 34) $card.Metric 8 'F1' '#94A3B8' 28
            Add-AerPdfText $ops ($cx + 10) ($cy + 13) $card.Value 18 'F2' '#38BDF8' 18
        }

        Add-AerPdfText $ops 488 505 'Executive Signals' 14 'F2' '#FFFFFF' 40
        Add-AerPdfTable $ops 488 485 @(
            [pscustomobject]@{ Header = 'Area'; Width = 78; Key = 'Area' },
            [pscustomobject]@{ Header = 'Signal'; Width = 118; Key = 'Signal' },
            [pscustomobject]@{ Header = 'Status'; Width = 72; Key = 'Status' },
            [pscustomobject]@{ Header = 'Action'; Width = 112; Key = 'Action' }
        ) $signals 12

        Add-AerPdfText $ops 36 300 'Portfolio Distribution' 14 'F2' '#FFFFFF' 40
        Add-AerPdfTable $ops 36 278 @(
            [pscustomobject]@{ Header = 'Resource Type'; Width = 170; Expression = { param($r) Get-AerFirstValue $r @('Type', 'Label') } },
            [pscustomobject]@{ Header = 'Count'; Width = 60; Key = 'Count' }
        ) (ConvertTo-AerArray (Get-AerValue $inv 'ByType')) 10
        Add-AerPdfTable $ops 302 278 @(
            [pscustomobject]@{ Header = 'Subscription'; Width = 190; Expression = { param($r) Get-AerFirstValue $r @('SubscriptionName', 'SubscriptionId') } },
            [pscustomobject]@{ Header = 'Count'; Width = 60; Key = 'Count' }
        ) (ConvertTo-AerArray (Get-AerValue $inv 'BySubscription')) 10
        Add-AerPdfTable $ops 588 278 @(
            [pscustomobject]@{ Header = 'Region'; Width = 120; Key = 'Region' },
            [pscustomobject]@{ Header = 'Count'; Width = 60; Key = 'Count' }
        ) (ConvertTo-AerArray (Get-AerValue $inv 'ByRegion')) 10

        Add-AerPdfText $ops 36 24 "Collection errors: $($errors.Count) · Full technical data available in XLSX export" 8 'F1' '#94A3B8' 120
    }))

    Add-AerPdfPageSet $pages (New-AerPdfTablePages -Title 'Executive Summary' -Subtitle 'Business-readable metrics' -Columns @(
        [pscustomobject]@{ Header = 'Metric'; Width = 210; Key = 'Metric' },
        [pscustomobject]@{ Header = 'Value'; Width = 90; Key = 'Value' },
        [pscustomobject]@{ Header = 'Signal'; Width = 220; Key = 'Signal' }
    ) -Rows $metrics -RowsPerPage 20 -MaxRows 100)

    Add-AerPdfPageSet $pages (New-AerPdfTablePages -Title 'Technical Inventory' -Subtitle 'Resource inventory, capped for printable PDF' -Columns @(
        [pscustomobject]@{ Header = 'Subscription'; Width = 145; Expression = { param($r) Get-AerSubscriptionName -ReportData $ReportData -SubscriptionId (Get-AerFirstValue $r @('subscriptionId', 'SubscriptionId')) } },
        [pscustomobject]@{ Header = 'Resource Group'; Width = 120; Expression = { param($r) Get-AerFirstValue $r @('resourceGroup', 'ResourceGroup') } },
        [pscustomobject]@{ Header = 'Name'; Width = 150; Expression = { param($r) Get-AerFirstValue $r @('name', 'Name') } },
        [pscustomobject]@{ Header = 'Type'; Width = 190; Expression = { param($r) Get-AerFirstValue $r @('type', 'Type') } },
        [pscustomobject]@{ Header = 'Region'; Width = 80; Expression = { param($r) Get-AerFirstValue $r @('location', 'Location') } },
        [pscustomobject]@{ Header = 'State'; Width = 80; Expression = { param($r) Get-AerFirstValue $r @('provisioningState', 'ProvisioningState', 'Status') } }
    ) -Rows (ConvertTo-AerArray (Get-AerValue $inv 'ResourceList')) -RowsPerPage 24 -MaxRows 1000)

    $sec = Get-AerValue $ReportData 'security'
    $cost = Get-AerValue $ReportData 'cost'
    $adv = Get-AerValue $ReportData 'advisor'
    Add-AerPdfPageSet $pages (New-AerPdfTablePages -Title 'Security Findings' -Subtitle 'General security gaps' -Columns @(
        [pscustomobject]@{ Header = 'Severity'; Width = 80; Key = 'Severity' },
        [pscustomobject]@{ Header = 'Finding'; Width = 320; Key = 'Title' },
        [pscustomobject]@{ Header = 'Affected Type'; Width = 220; Expression = { param($r) Get-AerFindingAffectedType $r } },
        [pscustomobject]@{ Header = 'Count'; Width = 70; Key = 'Count' }
    ) -Rows (ConvertTo-AerArray (Get-AerValue $sec 'Items')) -RowsPerPage 24 -MaxRows 300)
    Add-AerPdfPageSet $pages (New-AerPdfTablePages -Title 'Cost Findings' -Subtitle 'Cost waste opportunities' -Columns @(
        [pscustomobject]@{ Header = 'Severity'; Width = 80; Key = 'Severity' },
        [pscustomobject]@{ Header = 'Finding'; Width = 320; Key = 'Title' },
        [pscustomobject]@{ Header = 'Affected Type'; Width = 220; Expression = { param($r) Get-AerFindingAffectedType $r } },
        [pscustomobject]@{ Header = 'Count'; Width = 70; Key = 'Count' }
    ) -Rows (ConvertTo-AerArray (Get-AerValue $cost 'Items')) -RowsPerPage 24 -MaxRows 300)
    Add-AerPdfPageSet $pages (New-AerPdfTablePages -Title 'Advisor Recommendations' -Subtitle 'Azure Advisor data' -Columns @(
        [pscustomobject]@{ Header = 'Category'; Width = 100; Key = 'Category' },
        [pscustomobject]@{ Header = 'Impact'; Width = 70; Key = 'Impact' },
        [pscustomobject]@{ Header = 'Recommendation'; Width = 330; Expression = { param($r) Get-AerAdvisorRecommendationText $r } },
        [pscustomobject]@{ Header = 'Resource'; Width = 140; Expression = { param($r) Get-AerAdvisorResourceName $r } },
        [pscustomobject]@{ Header = 'Subscription'; Width = 130; Expression = { param($r) Get-AerAdvisorSubscriptionName -ReportData $ReportData -Recommendation $r } }
    ) -Rows (ConvertTo-AerArray (Get-AerValue $adv 'Recommendations')) -RowsPerPage 24 -MaxRows 500)

    $encoding = [System.Text.Encoding]::ASCII
    $objects = @{}
    $objects[1] = '<< /Type /Catalog /Pages 2 0 R >>'
    $objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
    $objects[4] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>'

    $kids = @()
    for ($i = 0; $i -lt $pages.Count; $i++) {
        $pageObj = 5 + ($i * 2)
        $contentObj = $pageObj + 1
        $kids += "$pageObj 0 R"
        $content = $pages[$i]
        $len = $encoding.GetByteCount($content)
        $objects[$pageObj] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents $contentObj 0 R >>"
        $objects[$contentObj] = "<< /Length $len >>`nstream`n$content`nendstream"
    }
    $objects[2] = "<< /Type /Pages /Kids [ $($kids -join ' ') ] /Count $($pages.Count) >>"

    $maxObj = ($objects.Keys | Measure-Object -Maximum).Maximum
    $parts = [System.Collections.Generic.List[string]]::new()
    $offsets = New-Object int[] ($maxObj + 1)
    $current = 0
    $add = {
        param([string] $Text)
        $parts.Add($Text)
        $script:pdfCurrent += $encoding.GetByteCount($Text)
    }

    $script:pdfCurrent = 0
    & $add "%PDF-1.4`n% AER`n"
    for ($i = 1; $i -le $maxObj; $i++) {
        $offsets[$i] = $script:pdfCurrent
        & $add "$i 0 obj`n$($objects[$i])`nendobj`n"
    }
    $xref = $script:pdfCurrent
    & $add "xref`n0 $($maxObj + 1)`n"
    & $add "0000000000 65535 f `n"
    for ($i = 1; $i -le $maxObj; $i++) {
        & $add ("{0:0000000000} 00000 n `n" -f $offsets[$i])
    }
    & $add "trailer`n<< /Size $($maxObj + 1) /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n"

    [System.IO.File]::WriteAllBytes($Path, $encoding.GetBytes(($parts -join '')))
    return $Path
}

function New-AerReportExports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $ReportData,
        [Parameter(Mandatory)] [string] $OutputPath
    )

    $exportDir = Join-Path $OutputPath 'exports'
    $xlsxPath = Join-Path $exportDir 'aer-report.xlsx'
    $pdfPath = Join-Path $exportDir 'aer-report.pdf'
    $errors = [System.Collections.Generic.List[object]]::new()
    $xlsxRel = $null
    $pdfRel = $null

    try {
        $null = New-AerExcelReport -ReportData $ReportData -Path $xlsxPath
        $xlsxRel = 'exports/aer-report.xlsx'
    } catch {
        $errors.Add([pscustomobject]@{ Export = 'XLSX'; Message = $_.Exception.Message })
    }

    try {
        $null = New-AerPdfReport -ReportData $ReportData -Path $pdfPath
        $pdfRel = 'exports/aer-report.pdf'
    } catch {
        $errors.Add([pscustomobject]@{ Export = 'PDF'; Message = $_.Exception.Message })
    }

    $metaValue = [pscustomobject]@{
        Xlsx        = $xlsxRel
        Pdf         = $pdfRel
        GeneratedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'
        Errors      = @($errors)
    }

    $meta = Get-AerValue $ReportData 'metadata'
    if ($meta) {
        Add-Member -InputObject $meta -MemberType NoteProperty -Name 'ExportFiles' -Value $metaValue -Force
    }

    return [pscustomobject]@{
        XlsxPath = if ($xlsxRel) { (Resolve-Path $xlsxPath).Path } else { $null }
        PdfPath  = if ($pdfRel) { (Resolve-Path $pdfPath).Path } else { $null }
        Xlsx     = $xlsxRel
        Pdf      = $pdfRel
        Errors   = @($errors)
    }
}
