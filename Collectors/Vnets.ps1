function Get-AerVnets {
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
    function Leaf($id) { if ($id) { ($id -split '/')[-1] } else { '' } }

    # ── Route tables → compact route list (for UDR per subnet) ───────────────
    $rtMap = @{}
    try {
        foreach ($rt in (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query "resources | where type =~ 'microsoft.network/routetables' | project id, name, routes = properties.routes")) {
            $routes = foreach ($r in @($rt.routes)) {
                $nh = "$($r.properties.nextHopType)"
                if ($nh -eq 'VirtualAppliance' -and $r.properties.nextHopIpAddress) { $nh = "VirtualAppliance ($($r.properties.nextHopIpAddress))" }
                [pscustomobject]@{ Prefix = "$($r.properties.addressPrefix)"; NextHop = $nh }
            }
            if ($rt.id) { $rtMap[$rt.id.ToLowerInvariant()] = [pscustomobject]@{ Name = $rt.name; Routes = @($routes) } }
        }
    } catch { Write-Warning "[Vnets.routeTables] $($_.Exception.Message)" }

    # ── Virtual networks (subnets + peerings inline) ─────────────────────────
    $vnets = [System.Collections.Generic.List[object]]::new()
    $nodes = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($v in (Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query "resources | where type =~ 'microsoft.network/virtualnetworks' | project id, name, subscriptionId, resourceGroup, location, addressPrefixes = properties.addressSpace.addressPrefixes, subnets = properties.subnets, peerings = properties.virtualNetworkPeerings, dnsServers = properties.dhcpOptions.dnsServers, tags")) {
            $vid = if ($v.id) { $v.id.ToLowerInvariant() } else { '' }

            $subnets = foreach ($s in @($v.subnets)) {
                $rtId = $s.properties.routeTable.id
                $rt = if ($rtId) { $rtMap[$rtId.ToLowerInvariant()] } else { $null }
                $prefix = if ($s.properties.addressPrefix) { $s.properties.addressPrefix }
                          elseif ($s.properties.addressPrefixes) { @($s.properties.addressPrefixes) -join ', ' }
                          else { '' }
                [pscustomobject]@{
                    SubnetName = $s.name
                    Prefix     = $prefix
                    RouteTable = if ($rt) { $rt.Name } else { '' }
                    Routes     = if ($rt) { @($rt.Routes) } else { @() }
                    Nsg        = (Leaf $s.properties.networkSecurityGroup.id)
                }
            }

            $peerings = foreach ($p in @($v.peerings)) {
                $remoteId = $p.properties.remoteVirtualNetwork.id
                if ($remoteId) {
                    $edges.Add([pscustomobject]@{
                        From = $vid; To = $remoteId.ToLowerInvariant()
                        GatewayTransit = [bool]$p.properties.allowGatewayTransit
                        UseRemoteGateways = [bool]$p.properties.useRemoteGateways
                        State = "$($p.properties.peeringState)"
                    })
                }
                [pscustomobject]@{
                    PeerName              = $p.name
                    RemoteVnet            = (Leaf $remoteId)
                    State                 = "$($p.properties.peeringState)"
                    AllowGatewayTransit   = [bool]$p.properties.allowGatewayTransit
                    UseRemoteGateways     = [bool]$p.properties.useRemoteGateways
                    AllowForwardedTraffic = [bool]$p.properties.allowForwardedTraffic
                    AllowVnetAccess       = [bool]$p.properties.allowVirtualNetworkAccess
                }
            }

            $subName = if ($v.subscriptionId) { $subLookup[$v.subscriptionId.ToLowerInvariant()] } else { $null }
            $vnets.Add([pscustomobject]@{
                Id               = $v.id
                Name             = $v.name
                SubscriptionId   = $v.subscriptionId
                SubscriptionName = $subName ?? $v.subscriptionId
                ResourceGroup    = $v.resourceGroup
                Location         = $v.location
                AddressSpace     = (@($v.addressPrefixes) -join ', ')
                DnsServers       = (@($v.dnsServers) -join ', ')
                Tags             = $v.tags
                Subnets          = @($subnets)
                Peerings         = @($peerings)
            })
            $nodes.Add([pscustomobject]@{ id = $vid; name = $v.name; sub = ($subName ?? $v.subscriptionId); rg = $v.resourceGroup })
        }
    } catch { Write-Warning "[Vnets.vnets] $($_.Exception.Message)" }

    # Keep only intra-estate peering edges (both ends scanned), de-duplicated per pair
    $nodeSet = @{}; foreach ($n in $nodes) { $nodeSet[$n.id] = $true }
    $seen = @{}; $cleanEdges = [System.Collections.Generic.List[object]]::new()
    foreach ($e in $edges) {
        if (-not $nodeSet[$e.To]) { continue }
        $key = (@($e.From, $e.To) | Sort-Object) -join '|'
        if ($seen[$key]) { continue }
        $seen[$key] = $true
        $cleanEdges.Add($e)
    }

    return [pscustomobject]@{
        Vnets = @($vnets)
        Graph = [pscustomobject]@{ Nodes = @($nodes); Edges = @($cleanEdges) }
    }
}
