function Get-AerNetwork {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        [Parameter(Mandatory)]            $SubscriptionMap
    )

    function SumQ($q) {
        try { $r = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $q; [int](($r | Select-Object -First 1).n ?? 0) }
        catch { Write-Warning "[Network.sum] $($_.Exception.Message)"; 0 }
    }
    function Get-RestListCount($path) {
        $n = 0
        try {
            while (-not [string]::IsNullOrWhiteSpace($path)) {
                $resp = Invoke-AzRestMethod -Method GET -Path $path -ErrorAction Stop
                if ($resp.StatusCode -ne 200) { break }
                $body = $resp.Content | ConvertFrom-Json
                $n += @($body.value).Count
                $path = if ($body.nextLink) { ([uri]$body.nextLink).PathAndQuery } else { $null }
            }
        } catch { Write-Warning "[Network.rest] $($_.Exception.Message)" }
        $n
    }

    # ── Counts by type ───────────────────────────────────────────────────────
    $cnt = @{}
    try {
        $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type in~ (
    'microsoft.network/virtualnetworks','microsoft.network/virtualnetworkgateways',
    'microsoft.network/expressroutecircuits','microsoft.network/privateendpoints',
    'microsoft.network/applicationgateways','microsoft.network/frontdoors','microsoft.cdn/profiles',
    'microsoft.network/loadbalancers','microsoft.network/azurefirewalls',
    'microsoft.network/networksecuritygroups','microsoft.network/publicipaddresses',
    'microsoft.network/routetables','microsoft.network/ddosprotectionplans',
    'microsoft.network/trafficmanagerprofiles','microsoft.apimanagement/service',
    'microsoft.network/dnszones','microsoft.network/privatednszones')
| summarize c = count() by type = tolower(type)
'@
        foreach ($r in $rows) { $cnt[$r.type] = [int]$r.c }
    } catch { Write-Warning "[Network.counts] $($_.Exception.Message)" }
    function C($t) { [int]($cnt[$t] ?? 0) }

    # ── VNet totals: subnets + peerings ──────────────────────────────────────
    $subnetTotal = 0; $peerTotal = 0
    try {
        $t = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.network/virtualnetworks'
| summarize Subnets = sum(array_length(properties.subnets)), Peerings = sum(array_length(properties.virtualNetworkPeerings))
'@
        $row = $t | Select-Object -First 1
        if ($row) { $subnetTotal = [int]($row.Subnets ?? 0); $peerTotal = [int]($row.Peerings ?? 0) }
    } catch { Write-Warning "[Network.vnetTotals] $($_.Exception.Message)" }

    # ── IP utilization: capacity vs used, computed in KQL (single safe row) ──
    # IPv4 only; capacity = 2^(32-mask) per subnet, used = ipConfigurations count.
    $cap = 0.0; $used = 0; $resvSubnets = 0
    try {
        $u = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.network/virtualnetworks'
| mv-expand subnet = properties.subnets
| extend prefix = tostring(subnet.properties.addressPrefix)
| where isnotempty(prefix) and prefix !contains ':'
| extend mask = toint(split(prefix, '/')[1])
| where isnotempty(mask)
| extend cap = tolong(pow(2, 32 - mask))
| extend ipc = toint(array_length(subnet.properties.ipConfigurations))
| summarize Capacity = sum(cap), Used = sum(ipc), Subnets = count()
'@
        $row = $u | Select-Object -First 1
        if ($row) { $cap = [double]($row.Capacity ?? 0); $used = [int]($row.Used ?? 0); $resvSubnets = [int]($row.Subnets ?? 0) }
    } catch { Write-Warning "[Network.ipUsage] $($_.Exception.Message)" }
    $reserved = 5 * $resvSubnets                       # Azure reserves 5 addresses per subnet
    $occupied = $used + $reserved
    $free     = [math]::Max(0, $cap - $occupied)
    $pct      = if ($cap -gt 0) { [math]::Round($occupied / $cap * 100, 1) } else { 0 }

    $frontDoor = (C 'microsoft.network/frontdoors') + (C 'microsoft.cdn/profiles')

    # Applications configured behind each balancer type (backends / endpoints / APIs)
    $lbApps  = SumQ "resources | where type =~ 'microsoft.network/loadbalancers' | summarize n = sum(array_length(properties.backendAddressPools))"
    $agwApps = SumQ "resources | where type =~ 'microsoft.network/applicationgateways' | summarize n = sum(array_length(properties.backendAddressPools))"
    $tmApps  = SumQ "resources | where type =~ 'microsoft.network/trafficmanagerprofiles' | summarize n = sum(array_length(properties.endpoints))"
    # Front Door: classic backend pools (ARG) + Std/Premium origin groups (REST per profile, sub-resource not in ARG)
    $afdApps = SumQ "resources | where type =~ 'microsoft.network/frontdoors' | summarize n = sum(array_length(properties.backendPools))"
    foreach ($p in (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query "resources | where type =~ 'microsoft.cdn/profiles' and sku.name in~ ('Standard_AzureFrontDoor','Premium_AzureFrontDoor') | project id, subscriptionId, resourceGroup, name")) {
        $afdApps += Get-RestListCount "/subscriptions/$($p.subscriptionId)/resourceGroups/$($p.resourceGroup)/providers/Microsoft.Cdn/profiles/$($p.name)/originGroups?api-version=2023-05-01"
    }
    # API Management: published APIs (REST per service, sub-resource not in ARG)
    $apimApps = 0
    foreach ($s in (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query "resources | where type =~ 'microsoft.apimanagement/service' | project id, subscriptionId, resourceGroup, name")) {
        $apimApps += Get-RestListCount "/subscriptions/$($s.subscriptionId)/resourceGroups/$($s.resourceGroup)/providers/Microsoft.ApiManagement/service/$($s.name)/apis?api-version=2022-08-01"
    }

    [pscustomobject]@{
        Counts = [pscustomobject]@{
            Vnet             = C 'microsoft.network/virtualnetworks'
            Subnets          = $subnetTotal
            Peerings         = $peerTotal
            Gateways         = C 'microsoft.network/virtualnetworkgateways'
            ExpressRoute     = C 'microsoft.network/expressroutecircuits'
            PrivateEndpoints = C 'microsoft.network/privateendpoints'
            AppGateway       = C 'microsoft.network/applicationgateways'
            FrontDoor        = $frontDoor
            LoadBalancer     = C 'microsoft.network/loadbalancers'
            AzureFirewall    = C 'microsoft.network/azurefirewalls'
            Nsg              = C 'microsoft.network/networksecuritygroups'
            PublicIp         = C 'microsoft.network/publicipaddresses'
            RouteTables      = C 'microsoft.network/routetables'
            DdosPlans        = C 'microsoft.network/ddosprotectionplans'
            TrafficManager   = C 'microsoft.network/trafficmanagerprofiles'
        }
        IpUsage = [pscustomobject]@{
            Capacity    = [long]$cap
            Used        = [int]$used
            Reserved    = [int]$reserved
            Occupied    = [long]$occupied
            Free        = [long]$free
            PercentUsed = $pct
            SubnetCount = $resvSubnets
        }
        Dns = [pscustomobject]@{
            Public  = C 'microsoft.network/dnszones'
            Private = C 'microsoft.network/privatednszones'
        }
        Balancers = @(
            [pscustomobject]@{ Type = 'Load Balancer (ALB)';   Count = $lbApps }
            [pscustomobject]@{ Type = 'App Gateway (AGW)';      Count = $agwApps }
            [pscustomobject]@{ Type = 'Front Door (AFD)';       Count = $afdApps }
            [pscustomobject]@{ Type = 'Traffic Manager (ATM)';  Count = $tmApps }
            [pscustomobject]@{ Type = 'API Management (APIM)';  Count = $apimApps }
        )
    }
}
