function Get-AerVirtualMachines {
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

    # ── Virtual machines (core fields + first NIC + image reference) ─────────
    $vmRows = @()
    try {
        $vmRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend img = properties.storageProfile.imageReference
| project id, name, subscriptionId, resourceGroup, location,
          osType      = tostring(properties.storageProfile.osDisk.osType),
          vmSize      = tostring(properties.hardwareProfile.vmSize),
          imgPublisher= tostring(img.publisher),
          imgOffer    = tostring(img.offer),
          imgSku      = tostring(img.sku),
          imgId       = tostring(img.id),
          bootDiag    = tobool(properties.diagnosticsProfile.bootDiagnostics.enabled),
          timeCreated = tostring(properties.timeCreated),
          powerState  = tostring(properties.extended.instanceView.powerState.code),
          nicId       = tolower(tostring(properties.networkProfile.networkInterfaces[0].id)),
          tags
'@
    } catch { Write-Warning "[VirtualMachines.vms] $($_.Exception.Message)" }

    # ── Network interfaces → private IP + associated public IP id ────────────
    $nicMap = @{}
    try {
        $nicRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.network/networkinterfaces'
| extend ipcfg = properties.ipConfigurations[0]
| project nicId = tolower(id),
          privateIp  = tostring(ipcfg.properties.privateIPAddress),
          publicIpId = tolower(tostring(ipcfg.properties.publicIPAddress.id)),
          subnetId   = tostring(ipcfg.properties.subnet.id)
'@
        foreach ($n in $nicRows) { if ($n.nicId) { $nicMap[$n.nicId] = $n } }
    } catch { Write-Warning "[VirtualMachines.nics] $($_.Exception.Message)" }

    # ── Public IP addresses → address ────────────────────────────────────────
    $pipMap = @{}
    try {
        $pipRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.network/publicipaddresses'
| project pipId = tolower(id), ip = tostring(properties.ipAddress)
'@
        foreach ($p in $pipRows) { if ($p.pipId) { $pipMap[$p.pipId] = $p.ip } }
    } catch { Write-Warning "[VirtualMachines.publicips] $($_.Exception.Message)" }

    # ── Managed disks → total provisioned size per owning VM ─────────────────
    $diskMap = @{}
    try {
        $diskRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.compute/disks'
| where isnotempty(tostring(managedBy))
| summarize DiskGB = sum(toint(properties.diskSizeGB)) by vmId = tolower(tostring(managedBy))
'@
        foreach ($d in $diskRows) { if ($d.vmId) { $diskMap[$d.vmId] = [int]$d.DiskGB } }
    } catch { Write-Warning "[VirtualMachines.disks] $($_.Exception.Message)" }

    # ── vCore / memory per SKU via Compute vmSizes REST (one call per region) ─
    # ARG doesn't expose SKU capabilities, so resolve them from the regional
    # vmSizes catalog. Key the map by "region|size" (lowercased).
    $sizeMap = @{}
    foreach ($grp in ($vmRows | Group-Object location)) {
        $region = $grp.Name
        $subForRegion = ($grp.Group | Select-Object -First 1).subscriptionId
        if (-not $region -or -not $subForRegion) { continue }
        try {
            $resp = Invoke-AzRestMethod -Method GET `
                -Path "/subscriptions/$subForRegion/providers/Microsoft.Compute/locations/$region/vmSizes?api-version=2023-07-01" `
                -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                foreach ($s in @(($resp.Content | ConvertFrom-Json).value)) {
                    $sizeMap["$region|$($s.name)".ToLowerInvariant()] = [pscustomobject]@{
                        Cores    = [int]$s.numberOfCores
                        MemoryMB = [int]$s.memoryInMB
                    }
                }
            }
        } catch { Write-Warning "[VirtualMachines.vmSizes:$region] $($_.Exception.Message)" }
    }

    # ── Assemble per-VM records ──────────────────────────────────────────────
    $vms = foreach ($v in $vmRows) {
        $nic       = if ($v.nicId) { $nicMap[$v.nicId] } else { $null }
        $privateIp = $nic.privateIp
        $publicIp  = if ($nic -and $nic.publicIpId) { $pipMap[$nic.publicIpId] } else { $null }
        $vnet = ''; $subnet = ''
        if ($nic -and $nic.subnetId) {
            $sp = $nic.subnetId -split '/'
            $iv = [array]::IndexOf($sp, 'virtualNetworks'); if ($iv -ge 0 -and ($iv + 1) -lt $sp.Count) { $vnet = $sp[$iv + 1] }
            $isub = [array]::IndexOf($sp, 'subnets');         if ($isub -ge 0 -and ($isub + 1) -lt $sp.Count) { $subnet = $sp[$isub + 1] }
        }

        $os = switch -Regex ($v.osType) {
            'Windows' { 'Windows'; break }
            'Linux'   { 'Linux';   break }
            default   { 'Other' }
        }

        $image =
            if ($v.imgPublisher) { "$($v.imgPublisher):$($v.imgOffer):$($v.imgSku)" }
            elseif ($v.imgId)    { 'Custom: ' + ($v.imgId -split '/')[-1] }
            else                 { '' }

        $vmIdLower = if ($v.id) { $v.id.ToLowerInvariant() } else { '' }
        $diskGB    = if ($vmIdLower -and $diskMap.ContainsKey($vmIdLower)) { [int]$diskMap[$vmIdLower] } else { 0 }

        $sz       = $sizeMap["$($v.location)|$($v.vmSize)".ToLowerInvariant()]
        $cores    = if ($sz) { [int]$sz.Cores } else { 0 }
        $memMB    = if ($sz) { [int]$sz.MemoryMB } else { 0 }
        $memGB    = if ($memMB) { [math]::Round($memMB / 1024, 1) } else { 0 }

        $subName = if ($v.subscriptionId) { $subLookup[$v.subscriptionId.ToLowerInvariant()] } else { $null }
        $power   = if ($v.powerState) { ($v.powerState -split '/')[-1] } else { '' }

        [pscustomobject]@{
            Id               = $v.id
            Name             = $v.name
            SubscriptionId   = $v.subscriptionId
            SubscriptionName = $subName ?? $v.subscriptionId
            ResourceGroup    = $v.resourceGroup
            Os               = $os
            Location         = $v.location
            Sku              = $v.vmSize
            Image            = $image
            Tags             = $v.tags
            PrivateIp        = $privateIp
            PublicIp         = $publicIp
            Vnet             = $vnet
            Subnet           = $subnet
            BootDiagnostics  = [bool]$v.bootDiag
            TimeCreated      = $v.timeCreated
            Status           = $power
            VCores           = $cores
            MemoryMB         = $memMB
            MemoryGB         = $memGB
            DiskGB           = $diskGB
        }
    }
    $vms = @($vms)

    $totalMemMB = ($vms | Measure-Object MemoryMB -Sum).Sum ?? 0

    return [pscustomobject]@{
        TotalVMs        = $vms.Count
        LinuxVMs        = @($vms | Where-Object { $_.Os -eq 'Linux' }).Count
        WindowsVMs      = @($vms | Where-Object { $_.Os -eq 'Windows' }).Count
        TotalvCores     = [int](($vms | Measure-Object VCores -Sum).Sum ?? 0)
        TotalMemoryGB   = [math]::Round($totalMemMB / 1024, 0)
        TotalDiskGB     = [int](($vms | Measure-Object DiskGB -Sum).Sum ?? 0)
        VirtualMachines = $vms
    }
}
