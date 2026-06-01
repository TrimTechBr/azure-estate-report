function Get-AerLoadBalancers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        [Parameter(Mandatory)]            $SubscriptionMap
    )

    $subLookup = @{}
    if ($SubscriptionMap -is [hashtable]) { $subLookup = $SubscriptionMap }
    elseif ($SubscriptionMap) { $SubscriptionMap.PSObject.Properties | ForEach-Object { $subLookup[$_.Name] = $_.Value } }

    function Resolve-SubName($sid) { if ($sid) { $subLookup[$sid.ToLowerInvariant()] ?? $sid } else { '' } }
    function Leaf($id) { if ($id) { ($id -split '/')[-1] } else { '' } }
    function ById($arr) { $m = @{}; foreach ($x in @($arr)) { if ($x.id) { $m[$x.id.ToLowerInvariant()] = $x } }; $m }
    function Get-ByRef($map, $ref) { if ($ref -and $ref.id) { $map[$ref.id.ToLowerInvariant()] } else { $null } }
    $arg = { param($q) try { Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $q } catch { Write-Warning "[LoadBalancers] $($_.Exception.Message)"; @() } }
    function RestGet($path) {
        $out = [System.Collections.Generic.List[object]]::new()
        try {
            while (-not [string]::IsNullOrWhiteSpace($path)) {
                $resp = Invoke-AzRestMethod -Method GET -Path $path -ErrorAction Stop
                if ($resp.StatusCode -ne 200) { break }
                $b = $resp.Content | ConvertFrom-Json
                foreach ($v in @($b.value)) { $out.Add($v) }
                $path = if ($b.nextLink) { ([uri]$b.nextLink).PathAndQuery } else { $null }
            }
        } catch { Write-Warning "[LoadBalancers.rest] $($_.Exception.Message)" }
        @($out)
    }

    $balancers = [System.Collections.Generic.List[object]]::new()
    function Add-Lb($type, $r, $sku, $endpoints) {
        $balancers.Add([pscustomobject]@{
            Type = $type; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Sku = $sku; Tags = $r.tags
            Endpoints = @($endpoints)
        })
    }

    # ── Azure Load Balancer (ALB) ────────────────────────────────────────────
    foreach ($r in (& $arg "resources | where type =~ 'microsoft.network/loadbalancers' | project id, name, subscriptionId, resourceGroup, location, sku = tostring(sku.name), rules = properties.loadBalancingRules, pools = properties.backendAddressPools, probes = properties.probes, tags")) {
        $poolMap = ById $r.pools; $probeMap = ById $r.probes
        $eps = foreach ($rule in @($r.rules)) {
            $pool = Get-ByRef $poolMap $rule.properties.backendAddressPool
            $servers = @()
            if ($pool) {
                foreach ($a in @($pool.properties.loadBalancerBackendAddresses)) { if ($a.properties.ipAddress) { $servers += $a.properties.ipAddress } }
                $nic = @($pool.properties.backendIPConfigurations).Count
                if (-not @($servers).Count -and $nic) { $servers += "$nic backend NIC(s)" }
            }
            $probe = Get-ByRef $probeMap $rule.properties.probe
            [pscustomobject]@{
                Name = $rule.name; Group = (Leaf $rule.properties.backendAddressPool.id)
                Protocol = "$($rule.properties.protocol)"
                FrontendPort = "$($rule.properties.frontendPort)"; BackendPort = "$($rule.properties.backendPort)"
                Health = if ($probe) { "$($probe.properties.protocol):$($probe.properties.port) probe" } else { '' }
                Servers = @(@($servers) | Select-Object -First 12)
            }
        }
        Add-Lb 'Azure Load Balancer' $r $r.sku @($eps)
    }

    # ── Application Gateway (AGW) ─────────────────────────────────────────────
    foreach ($r in (& $arg "resources | where type =~ 'microsoft.network/applicationgateways' | project id, name, subscriptionId, resourceGroup, location, sku = tostring(sku.name), listeners = properties.httpListeners, fports = properties.frontendPorts, pools = properties.backendAddressPools, settings = properties.backendHttpSettingsCollection, rules = properties.requestRoutingRules, probes = properties.probes, tags")) {
        $lMap = ById $r.listeners; $fpMap = ById $r.fports; $poolMap = ById $r.pools; $setMap = ById $r.settings
        $eps = foreach ($rule in @($r.rules)) {
            $listener = Get-ByRef $lMap $rule.properties.httpListener
            $fport = if ($listener) { Get-ByRef $fpMap $listener.properties.frontendPort } else { $null }
            $pool = Get-ByRef $poolMap $rule.properties.backendAddressPool
            $set = Get-ByRef $setMap $rule.properties.backendHttpSettings
            $servers = @()
            if ($pool) { foreach ($a in @($pool.properties.backendAddresses)) { $servers += ($a.fqdn ?? $a.ipAddress) } }
            $proto = if ($listener) { "$($listener.properties.protocol)" } else { '' }
            $lhost = if ($listener -and $listener.properties.hostName) { $listener.properties.hostName } else { '' }
            [pscustomobject]@{
                Name = $rule.name; Group = (Leaf $rule.properties.backendAddressPool.id) + $(if ($lhost) { " · $lhost" } else { '' })
                Protocol = $proto
                FrontendPort = if ($fport) { "$($fport.properties.port)" } else { '' }
                BackendPort = if ($set) { "$($set.properties.port)" } else { '' }
                Health = if ($set -and $set.properties.probe) { 'custom probe' } else { 'default probe' }
                Servers = @(@($servers | Where-Object { $_ }) | Select-Object -First 12)
            }
        }
        Add-Lb 'Application Gateway' $r $r.sku @($eps)
    }

    # ── Azure Front Door (classic) ───────────────────────────────────────────
    foreach ($r in (& $arg "resources | where type =~ 'microsoft.network/frontdoors' | project id, name, subscriptionId, resourceGroup, location, backendPools = properties.backendPools, tags")) {
        $eps = foreach ($pool in @($r.backendPools)) {
            $servers = foreach ($b in @($pool.properties.backends)) { "$($b.address):$($b.httpsPort)" }
            [pscustomobject]@{
                Name = $pool.name; Group = $pool.name; Protocol = 'HTTP/HTTPS'
                FrontendPort = '80/443'; BackendPort = ''
                Health = ''
                Servers = @(@($servers) | Select-Object -First 12)
            }
        }
        Add-Lb 'Azure Front Door (classic)' $r 'Classic' @($eps)
    }

    # ── Azure Front Door (Standard/Premium) — origins via REST ───────────────
    foreach ($p in (& $arg "resources | where type =~ 'microsoft.cdn/profiles' and sku.name in~ ('Standard_AzureFrontDoor','Premium_AzureFrontDoor') | project id, name, subscriptionId, resourceGroup, location, sku = tostring(sku.name), tags")) {
        $base = "/subscriptions/$($p.subscriptionId)/resourceGroups/$($p.resourceGroup)/providers/Microsoft.Cdn/profiles/$($p.name)"
        $eps = foreach ($og in (RestGet "$base/originGroups?api-version=2023-05-01")) {
            $servers = foreach ($o in (RestGet "$base/originGroups/$($og.name)/origins?api-version=2023-05-01")) { "$($o.properties.hostName):$($o.properties.httpsPort)" }
            $hp = $og.properties.healthProbeSettings
            [pscustomobject]@{
                Name = $og.name; Group = $og.name; Protocol = 'HTTP/HTTPS'
                FrontendPort = '80/443'; BackendPort = ''
                Health = if ($hp) { "$($hp.probeProtocol) $($hp.probePath)" } else { '' }
                Servers = @(@($servers) | Select-Object -First 12)
            }
        }
        Add-Lb 'Azure Front Door (Std/Premium)' $p $p.sku @($eps)
    }

    # ── Traffic Manager (ATM) ────────────────────────────────────────────────
    foreach ($r in (& $arg "resources | where type =~ 'microsoft.network/trafficmanagerprofiles' | project id, name, subscriptionId, resourceGroup, location, method = tostring(properties.trafficRoutingMethod), monitor = properties.monitorConfig, endpoints = properties.endpoints, tags")) {
        $mport = "$($r.monitor.port)"; $mproto = "$($r.monitor.protocol)"
        $eps = foreach ($ep in @($r.endpoints)) {
            [pscustomobject]@{
                Name = $ep.name; Group = "$($r.method) routing"; Protocol = $mproto
                FrontendPort = ''; BackendPort = $mport
                Health = "$($ep.properties.endpointMonitorStatus)"
                Servers = @("$($ep.properties.target)")
            }
        }
        Add-Lb 'Traffic Manager' $r "$($r.method)" @($eps)
    }

    $all = @($balancers)
    $cnt = { param($t) @($all | Where-Object { $_.Type -eq $t }).Count }
    return [pscustomobject]@{
        Total  = $all.Count
        Counts = [pscustomobject]@{
            LoadBalancer   = (& $cnt 'Azure Load Balancer')
            AppGateway     = (& $cnt 'Application Gateway')
            FrontDoor      = (& $cnt 'Azure Front Door (classic)') + (& $cnt 'Azure Front Door (Std/Premium)')
            TrafficManager = (& $cnt 'Traffic Manager')
        }
        Balancers = $all
    }
}
