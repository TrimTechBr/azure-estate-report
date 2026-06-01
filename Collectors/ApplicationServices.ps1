function Get-AerApplicationServices {
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

    function Resolve-SubName($sid) { if ($sid) { $subLookup[$sid.ToLowerInvariant()] ?? $sid } else { '' } }
    function YesNo($b) { if ($b -eq $true) { 'Yes' } elseif ($b -eq $false) { 'No' } else { '' } }
    function Leaf($id) { if ($id) { ($id -split '/')[-1] } else { '' } }
    $arg = { param($q) try { Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $q } catch { Write-Warning "[ApplicationServices] $($_.Exception.Message)"; @() } }
    function New-Service($type, $r, $details) {
        [pscustomobject]@{
            Type = $type; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            Details = @($details)
        }
    }

    $web = [System.Collections.Generic.List[object]]::new()
    $func = [System.Collections.Generic.List[object]]::new()
    $cont = [System.Collections.Generic.List[object]]::new()
    $integ = [System.Collections.Generic.List[object]]::new()
    $aks = [System.Collections.Generic.List[object]]::new()

    # ── microsoft.web/sites (Web App / Function App / Container / Logic Std) ──
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.web/sites'
| project id, name, subscriptionId, resourceGroup, location,
          acctKind = tostring(kind),
          status = tostring(properties.state),
          serverFarmId = tostring(properties.serverFarmId),
          linuxFx = tostring(properties.siteConfig.linuxFxVersion),
          defaultHost = tostring(properties.defaultHostName),
          httpsOnly = tobool(properties.httpsOnly),
          vnetSubnetId = tostring(properties.virtualNetworkSubnetId),
          tags
'@)) {
        $k = "$($r.acctKind)".ToLower()
        $plan = (Leaf $r.serverFarmId)
        $webVnet = (Get-AerSubnetLabel $r.vnetSubnetId)
        if ($k -match 'workflowapp') {
            $func.Add((New-Service 'Logic App (Standard)' $r @(
                [pscustomobject]@{ label = 'Status'; value = $r.status }
                [pscustomobject]@{ label = 'Plan'; value = $plan }
                [pscustomobject]@{ label = 'Default host'; value = $r.defaultHost }
                [pscustomobject]@{ label = 'VNet integration'; value = $webVnet }
            )))
        } elseif ($k -match 'functionapp') {
            $func.Add((New-Service 'Function App' $r @(
                [pscustomobject]@{ label = 'Status'; value = $r.status }
                [pscustomobject]@{ label = 'Plan'; value = $plan }
                [pscustomobject]@{ label = 'Runtime'; value = $r.linuxFx }
                [pscustomobject]@{ label = 'Default host'; value = $r.defaultHost }
                [pscustomobject]@{ label = 'HTTPS only'; value = (YesNo $r.httpsOnly) }
                [pscustomobject]@{ label = 'VNet integration'; value = $webVnet }
            )))
        } elseif ($k -match 'container') {
            $web.Add((New-Service 'Web App for Containers' $r @(
                [pscustomobject]@{ label = 'Status'; value = $r.status }
                [pscustomobject]@{ label = 'Plan'; value = $plan }
                [pscustomobject]@{ label = 'Container image'; value = $r.linuxFx }
                [pscustomobject]@{ label = 'Default host'; value = $r.defaultHost }
                [pscustomobject]@{ label = 'HTTPS only'; value = (YesNo $r.httpsOnly) }
                [pscustomobject]@{ label = 'VNet integration'; value = $webVnet }
            )))
        } else {
            $runtime = if ($r.linuxFx) { $r.linuxFx } else { 'Windows' }
            $web.Add((New-Service 'Web App' $r @(
                [pscustomobject]@{ label = 'Status'; value = $r.status }
                [pscustomobject]@{ label = 'Plan'; value = $plan }
                [pscustomobject]@{ label = 'Runtime'; value = $runtime }
                [pscustomobject]@{ label = 'Default host'; value = $r.defaultHost }
                [pscustomobject]@{ label = 'HTTPS only'; value = (YesNo $r.httpsOnly) }
                [pscustomobject]@{ label = 'VNet integration'; value = $webVnet }
            )))
        }
    }

    # ── App Service Plans ────────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.web/serverfarms'
| project id, name, subscriptionId, resourceGroup, location,
          acctKind = tostring(kind),
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier), skuCapacity = toint(sku.capacity),
          tags
'@)) {
        $os = if ("$($r.acctKind)".ToLower() -match 'linux') { 'Linux' } else { 'Windows' }
        $web.Add((New-Service 'App Service Plan' $r @(
            [pscustomobject]@{ label = 'SKU'; value = $r.skuName }
            [pscustomobject]@{ label = 'Tier'; value = $r.skuTier }
            [pscustomobject]@{ label = 'Instances'; value = $r.skuCapacity }
            [pscustomobject]@{ label = 'OS'; value = $os }
        )))
    }

    # ── App Service Environments ─────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.web/hostingenvironments'
| project id, name, subscriptionId, resourceGroup, location,
          acctKind = tostring(kind),
          status = tostring(properties.provisioningState),
          internalLb = tostring(properties.internalLoadBalancingMode),
          tags
'@)) {
        $web.Add((New-Service 'App Service Environment' $r @(
            [pscustomobject]@{ label = 'Status'; value = $r.status }
            [pscustomobject]@{ label = 'Kind'; value = $r.acctKind }
            [pscustomobject]@{ label = 'Internal LB'; value = $r.internalLb }
        )))
    }

    # ── Static Web Apps ──────────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.web/staticsites'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name),
          defaultHost = tostring(properties.defaultHostname),
          repoUrl = tostring(properties.repositoryUrl),
          tags
'@)) {
        $web.Add((New-Service 'Static Web App' $r @(
            [pscustomobject]@{ label = 'SKU'; value = $r.skuName }
            [pscustomobject]@{ label = 'Default host'; value = $r.defaultHost }
            [pscustomobject]@{ label = 'Repository'; value = $r.repoUrl }
        )))
    }

    # ── Logic Apps (Consumption) ─────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.logic/workflows'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state), tags
'@)) {
        $func.Add((New-Service 'Logic App (Consumption)' $r @(
            [pscustomobject]@{ label = 'State'; value = $r.status }
        )))
    }

    # ── Container Apps ───────────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.app/containerapps'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          env = tostring(properties.managedEnvironmentId),
          fqdn = tostring(properties.configuration.ingress.fqdn),
          tags
'@)) {
        $cont.Add((New-Service 'Container Apps' $r @(
            [pscustomobject]@{ label = 'Status'; value = $r.status }
            [pscustomobject]@{ label = 'Environment'; value = (Leaf $r.env) }
            [pscustomobject]@{ label = 'FQDN'; value = $r.fqdn }
        )))
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.app/managedenvironments'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState), tags
'@)) {
        $cont.Add((New-Service 'Container Apps Environment' $r @(
            [pscustomobject]@{ label = 'Status'; value = $r.status }
        )))
    }

    # ── Container Instances ──────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.containerinstance/containergroups'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          osType = tostring(properties.osType),
          ip = tostring(properties.ipAddress.ip),
          containerCount = toint(array_length(properties.containers)),
          tags
'@)) {
        $cont.Add((New-Service 'Container Instances' $r @(
            [pscustomobject]@{ label = 'Status'; value = $r.status }
            [pscustomobject]@{ label = 'OS'; value = $r.osType }
            [pscustomobject]@{ label = 'Containers'; value = $r.containerCount }
            [pscustomobject]@{ label = 'IP'; value = $r.ip }
        )))
    }

    # ── Container Registries ─────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.containerregistry/registries'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name),
          loginServer = tostring(properties.loginServer),
          adminEnabled = tobool(properties.adminUserEnabled),
          publicAccess = tostring(properties.publicNetworkAccess),
          tags
'@)) {
        $cont.Add((New-Service 'Container Registry' $r @(
            [pscustomobject]@{ label = 'SKU'; value = $r.skuName }
            [pscustomobject]@{ label = 'Login server'; value = $r.loginServer }
            [pscustomobject]@{ label = 'Admin user'; value = (YesNo $r.adminEnabled) }
            [pscustomobject]@{ label = 'Public access'; value = $r.publicAccess }
        )))
    }

    # ── Service Fabric ───────────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.servicefabric/clusters'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.clusterState),
          version = tostring(properties.clusterCodeVersion),
          tags
'@)) {
        $cont.Add((New-Service 'Service Fabric' $r @(
            [pscustomobject]@{ label = 'Status'; value = $r.status }
            [pscustomobject]@{ label = 'Version'; value = $r.version }
        )))
    }

    # ── API Management ───────────────────────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.apimanagement/service'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name), skuCapacity = toint(sku.capacity),
          gateway = tostring(properties.gatewayUrl),
          vnetType = tostring(properties.virtualNetworkType),
          tags
'@)) {
        $integ.Add((New-Service 'API Management' $r @(
            [pscustomobject]@{ label = 'SKU'; value = $r.skuName }
            [pscustomobject]@{ label = 'Capacity'; value = $r.skuCapacity }
            [pscustomobject]@{ label = 'Gateway'; value = $r.gateway }
            [pscustomobject]@{ label = 'VNet type'; value = $r.vnetType }
            [pscustomobject]@{ label = 'Status'; value = $r.status }
        )))
    }

    # ── AKS clusters (with node pools) ───────────────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.containerservice/managedclusters'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          powerState = tostring(properties.powerState.code),
          kubeVersion = tostring(properties.kubernetesVersion),
          skuTier = tostring(sku.tier),
          networkPlugin = tostring(properties.networkProfile.networkPlugin),
          rbac = tobool(properties.enableRBAC),
          privateCluster = tobool(properties.apiServerAccessProfile.enablePrivateCluster),
          nodeRg = tostring(properties.nodeResourceGroup),
          agentPools = properties.agentPoolProfiles,
          tags
'@)) {
        $pools = @($r.agentPools)
        $totalNodes = ($pools | Measure-Object -Property count -Sum).Sum ?? 0
        $aksPower = if ($r.powerState) { ($r.powerState -split '/')[-1] } else { '' }
        $details = [System.Collections.Generic.List[object]]::new()
        $details.Add([pscustomobject]@{ label = 'Status'; value = $r.status })
        $details.Add([pscustomobject]@{ label = 'Power state'; value = $aksPower })
        $details.Add([pscustomobject]@{ label = 'Kubernetes version'; value = $r.kubeVersion })
        $details.Add([pscustomobject]@{ label = 'SKU tier'; value = $r.skuTier })
        $details.Add([pscustomobject]@{ label = 'Network plugin'; value = $r.networkPlugin })
        $details.Add([pscustomobject]@{ label = 'RBAC'; value = (YesNo $r.rbac) })
        $details.Add([pscustomobject]@{ label = 'Private cluster'; value = (YesNo $r.privateCluster) })
        $details.Add([pscustomobject]@{ label = 'Node pools'; value = $pools.Count })
        $details.Add([pscustomobject]@{ label = 'Total nodes'; value = [int]$totalNodes })
        $details.Add([pscustomobject]@{ label = 'Node resource group'; value = $r.nodeRg })
        $aksVnet = (@($pools | ForEach-Object { Get-AerSubnetLabel ([string]$_.vnetSubnetID) } | Where-Object { $_ } | Select-Object -Unique) -join ', ')
        $details.Add([pscustomobject]@{ label = 'VNet integration'; value = $aksVnet })
        foreach ($p in $pools) {
            $details.Add([pscustomobject]@{ label = "Pool · $($p.name)"; value = "$($p.count) × $($p.vmSize) ($($p.mode))" })
        }
        $aks.Add((New-Service 'Azure Kubernetes Service' $r @($details)))
    }

    $webA = @($web); $funcA = @($func); $contA = @($cont); $integA = @($integ); $aksA = @($aks)
    $cnt = { param($list, $type) @($list | Where-Object { $_.Type -eq $type }).Count }

    return [pscustomobject]@{
        Web = [pscustomobject]@{
            Total = $webA.Count
            Counts = [pscustomobject]@{
                WebApp           = (& $cnt $webA 'Web App')
                WebAppContainers = (& $cnt $webA 'Web App for Containers')
                AppServicePlan   = (& $cnt $webA 'App Service Plan')
                Ase              = (& $cnt $webA 'App Service Environment')
                StaticWebApp     = (& $cnt $webA 'Static Web App')
            }
            Services = $webA
        }
        Functions = [pscustomobject]@{
            Total = $funcA.Count
            Counts = [pscustomobject]@{
                FunctionApp      = (& $cnt $funcA 'Function App')
                LogicStandard    = (& $cnt $funcA 'Logic App (Standard)')
                LogicConsumption = (& $cnt $funcA 'Logic App (Consumption)')
            }
            Services = $funcA
        }
        Containers = [pscustomobject]@{
            Total = $contA.Count
            Counts = [pscustomobject]@{
                ContainerApps      = (& $cnt $contA 'Container Apps')
                ContainerAppsEnv   = (& $cnt $contA 'Container Apps Environment')
                ContainerInstances = (& $cnt $contA 'Container Instances')
                ContainerRegistry  = (& $cnt $contA 'Container Registry')
                ServiceFabric      = (& $cnt $contA 'Service Fabric')
            }
            Services = $contA
        }
        Integration = [pscustomobject]@{
            Total = $integA.Count
            Counts = [pscustomobject]@{ ApiManagement = (& $cnt $integA 'API Management') }
            Services = $integA
        }
        Aks = [pscustomobject]@{
            Total = $aksA.Count
            Services = $aksA
        }
    }
}
