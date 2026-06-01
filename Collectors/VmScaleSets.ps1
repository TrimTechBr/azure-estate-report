function Get-AerVmScaleSets {
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

    # ── Scale sets ───────────────────────────────────────────────────────────
    $vmssRows = @()
    try {
        $vmssRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend img = properties.virtualMachineProfile.storageProfile.imageReference
| project id, name, subscriptionId, resourceGroup, location,
          orchestrationMode = tostring(properties.orchestrationMode),
          osType            = tostring(properties.virtualMachineProfile.storageProfile.osDisk.osType),
          skuName           = tostring(sku.name),
          capacity          = toint(sku.capacity),
          imgPublisher      = tostring(img.publisher),
          imgOffer          = tostring(img.offer),
          imgSku            = tostring(img.sku),
          imgId             = tostring(img.id),
          provisioningState = tostring(properties.provisioningState),
          timeCreated       = tostring(properties.timeCreated),
          subnetId          = tostring(properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.subnet.id),
          tags
'@
    } catch { Write-Warning "[VmScaleSets.vmss] $($_.Exception.Message)" }

    # ── Nodes: Uniform instances + Flexible member VMs, grouped by parent VMSS ─
    $nodesByVmss = @{}
    function Add-Node($map, $vmssId, $name, $computerName, $size, $powerStateCode) {
        if (-not $vmssId) { return }
        if (-not $map.ContainsKey($vmssId)) { $map[$vmssId] = [System.Collections.Generic.List[object]]::new() }
        $map[$vmssId].Add([pscustomobject]@{
            Name         = $name
            ComputerName = $computerName
            Size         = $size
            PowerState   = if ($powerStateCode) { ($powerStateCode -split '/')[-1] } else { '' }
        })
    }

    # Uniform (and legacy) instances are not reliably surfaced in Resource Graph,
    # so list them per scale set via the Compute REST API (instanceView → power state).
    foreach ($v in $vmssRows) {
        $vmode = if ($v.orchestrationMode) { $v.orchestrationMode } else { 'Uniform' }
        if ($vmode -eq 'Flexible') { continue }   # Flexible members are standalone VMs (collected via ARG below)
        if (-not $v.id -or -not $v.subscriptionId -or -not $v.resourceGroup -or -not $v.name) { continue }
        $idLower = $v.id.ToLowerInvariant()
        $path = "/subscriptions/$($v.subscriptionId)/resourceGroups/$($v.resourceGroup)/providers/Microsoft.Compute/virtualMachineScaleSets/$($v.name)/virtualMachines?api-version=2023-09-01&`$expand=instanceView"
        try {
            while (-not [string]::IsNullOrWhiteSpace($path)) {
                $resp = Invoke-AzRestMethod -Method GET -Path $path -ErrorAction Stop
                if ($resp.StatusCode -ne 200) { break }
                $body = $resp.Content | ConvertFrom-Json
                foreach ($inst in @($body.value)) {
                    $psCode = ($inst.properties.instanceView.statuses | Where-Object { $_.code -like 'PowerState/*' } | Select-Object -First 1).code
                    Add-Node $nodesByVmss $idLower $inst.name $inst.properties.osProfile.computerName $inst.sku.name $psCode
                }
                $path = if ($body.nextLink) { ([uri]$body.nextLink).PathAndQuery } else { $null }
            }
        } catch { Write-Warning "[VmScaleSets.instances:$($v.name)] $($_.Exception.Message)" }
    }

    try {
        $flexRows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where isnotempty(tostring(properties.virtualMachineScaleSet.id))
| project vmssId       = tolower(tostring(properties.virtualMachineScaleSet.id)),
          name         = tostring(name),
          computerName = tostring(properties.osProfile.computerName),
          vmSize       = tostring(properties.hardwareProfile.vmSize),
          powerState   = tostring(properties.extended.instanceView.powerState.code)
'@
        foreach ($n in $flexRows) { Add-Node $nodesByVmss $n.vmssId $n.name $n.computerName $n.vmSize $n.powerState }
    } catch { Write-Warning "[VmScaleSets.flexNodes] $($_.Exception.Message)" }

    # ── Assemble per-scale-set records ───────────────────────────────────────
    $sets = foreach ($v in $vmssRows) {
        $idLower = if ($v.id) { $v.id.ToLowerInvariant() } else { '' }
        $nodes   = if ($idLower -and $nodesByVmss.ContainsKey($idLower)) { @($nodesByVmss[$idLower]) } else { @() }

        $os = switch -Regex ($v.osType) {
            'Windows' { 'Windows'; break }
            'Linux'   { 'Linux';   break }
            default   { 'Other' }
        }
        $mode  = if ($v.orchestrationMode) { $v.orchestrationMode } else { 'Uniform' }
        $image =
            if ($v.imgPublisher) { "$($v.imgPublisher):$($v.imgOffer):$($v.imgSku)" }
            elseif ($v.imgId)    { 'Custom: ' + ($v.imgId -split '/')[-1] }
            else                 { '' }

        # Flexible sets report capacity differently — fall back to the node count
        $cap = [int]$v.capacity
        if ($cap -le 0) { $cap = $nodes.Count }

        $subName = if ($v.subscriptionId) { $subLookup[$v.subscriptionId.ToLowerInvariant()] } else { $null }

        $vnet = ''; $subnet = ''
        if ($v.subnetId) {
            $sp = $v.subnetId -split '/'
            $iv = [array]::IndexOf($sp, 'virtualNetworks'); if ($iv -ge 0 -and ($iv + 1) -lt $sp.Count) { $vnet = $sp[$iv + 1] }
            $isub = [array]::IndexOf($sp, 'subnets');         if ($isub -ge 0 -and ($isub + 1) -lt $sp.Count) { $subnet = $sp[$isub + 1] }
        }

        [pscustomobject]@{
            Id                = $v.id
            Name              = $v.name
            SubscriptionId    = $v.subscriptionId
            SubscriptionName  = $subName ?? $v.subscriptionId
            ResourceGroup     = $v.resourceGroup
            Os                = $os
            Location          = $v.location
            Sku               = $v.skuName
            OrchestrationMode = $mode
            Capacity          = $cap
            Vnet              = $vnet
            Subnet            = $subnet
            Image             = $image
            ProvisioningState = $v.provisioningState
            TimeCreated       = $v.timeCreated
            Tags              = $v.tags
            NodeCount         = $nodes.Count
            Nodes             = $nodes
        }
    }
    $sets = @($sets)

    return [pscustomobject]@{
        TotalVMSS      = $sets.Count
        WindowsVMSS    = @($sets | Where-Object { $_.Os -eq 'Windows' }).Count
        LinuxVMSS      = @($sets | Where-Object { $_.Os -eq 'Linux' }).Count
        UniformVMSS    = @($sets | Where-Object { $_.OrchestrationMode -eq 'Uniform' }).Count
        FlexibleVMSS   = @($sets | Where-Object { $_.OrchestrationMode -eq 'Flexible' }).Count
        TotalInstances = [int](($sets | Measure-Object Capacity -Sum).Sum ?? 0)
        ScaleSets      = $sets
    }
}
