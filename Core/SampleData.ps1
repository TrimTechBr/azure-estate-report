function New-AerSampleReportData {
    [CmdletBinding()]
    param(
        [string] $ModuleVersion = '0.1.0',
        [datetime] $GeneratedAt = (Get-Date)
    )

function New-FakeTags {
    param(
        [string] $Environment = 'prod',
        [string] $Owner = 'platform',
        [string] $CostCenter = 'cc-1001',
        [string] $Criticality = 'medium'
    )
    [pscustomobject]@{
        environment = $Environment
        owner       = $Owner
        costCenter  = $CostCenter
        criticality = $Criticality
        managedBy   = 'aer-fixture'
    }
}

function New-FakeId {
    param(
        [string] $SubscriptionId,
        [string] $ResourceGroup,
        [string] $Type,
        [string] $Name
    )
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/$Type/$Name"
}

function New-FakeResource {
    param(
        [object] $Subscription,
        [string] $ResourceGroup,
        [string] $Name,
        [string] $Type,
        [string] $Location,
        [string] $State = 'Succeeded',
        [object] $Tags = $null
    )
    [pscustomobject]@{
        id                = New-FakeId -SubscriptionId $Subscription.Id -ResourceGroup $ResourceGroup -Type $Type -Name $Name
        subscriptionId    = $Subscription.Id
        resourceGroup     = $ResourceGroup
        name              = $Name
        type              = $Type.ToLowerInvariant()
        location          = $Location
        provisioningState = $State
        tags              = if ($Tags) { $Tags } else { New-FakeTags }
    }
}

function New-ServiceRow {
    param(
        [string] $Type,
        [object] $Resource,
        [object[]] $Details = @()
    )
    [pscustomobject]@{
        Type             = $Type
        Name             = $Resource.name
        Id               = $Resource.id
        SubscriptionId   = $Resource.subscriptionId
        SubscriptionName = $script:SubMap[$Resource.subscriptionId.ToLowerInvariant()]
        ResourceGroup    = $Resource.resourceGroup
        Location         = $Resource.location
        Status           = $Resource.provisioningState
        Tags             = $Resource.tags
        Details          = @($Details)
    }
}

function New-Kv {
    param([string] $Label, [object] $Value)
    [pscustomobject]@{ label = $Label; value = $Value }
}

function To-FindingResource {
    param([object] $Resource)
    [pscustomobject]@{
        Name             = $Resource.name
        Type             = $Resource.type
        ResourceGroup    = $Resource.resourceGroup
        SubscriptionName = $script:SubMap[$Resource.subscriptionId.ToLowerInvariant()]
        Id               = $Resource.id
    }
}

$subscriptions = @(
    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Contoso Platform Prod' },
    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Contoso Apps Prod' },
    [pscustomobject]@{ Id = '33333333-3333-3333-3333-333333333333'; Name = 'Contoso Data Prod' },
    [pscustomobject]@{ Id = '44444444-4444-4444-4444-444444444444'; Name = 'Contoso Sandbox' }
)

$script:SubMap = @{}
foreach ($s in $subscriptions) { $script:SubMap[$s.Id.ToLowerInvariant()] = $s.Name }

$regions = @('eastus', 'eastus2', 'westus3', 'brazilsouth', 'westeurope')
$rgs     = @('rg-platform-prod', 'rg-apps-prod', 'rg-data-prod', 'rg-network-prod', 'rg-observability', 'rg-sandbox')
$resourceList = [System.Collections.Generic.List[object]]::new()

function Add-Res {
    param($Subscription, [string]$ResourceGroup, [string]$Name, [string]$Type, [string]$Location, [string]$State = 'Succeeded', $Tags = $null)
    $r = New-FakeResource -Subscription $Subscription -ResourceGroup $ResourceGroup -Name $Name -Type $Type -Location $Location -State $State -Tags $Tags
    $resourceList.Add($r)
    $r
}

$vms = [System.Collections.Generic.List[object]]::new()
for ($i = 1; $i -le 18; $i++) {
    $sub = $subscriptions[$i % $subscriptions.Count]
    $rg = @('rg-apps-prod', 'rg-data-prod', 'rg-platform-prod')[$i % 3]
    $loc = $regions[$i % $regions.Count]
    $os = if ($i % 3 -eq 0) { 'Windows' } else { 'Linux' }
    $name = if ($os -eq 'Windows') { 'vm-win-{0:00}' -f $i } else { 'vm-linux-{0:00}' -f $i }
    $res = Add-Res $sub $rg $name 'Microsoft.Compute/virtualMachines' $loc 'Succeeded' (New-FakeTags -Environment 'prod' -Owner @('payments','erp','data')[$i % 3] -Criticality @('high','medium','low')[$i % 3])
    $cores = @(2, 4, 8, 16)[$i % 4]
    $memGb = @(8, 16, 32, 64)[$i % 4]
    $disk = @(128, 256, 512, 1024)[$i % 4]
    $vms.Add([pscustomobject]@{
        Id               = $res.id
        Name             = $res.name
        SubscriptionId   = $sub.Id
        SubscriptionName = $sub.Name
        ResourceGroup    = $rg
        Os               = $os
        Location         = $loc
        Sku              = @('Standard_D2s_v5','Standard_D4s_v5','Standard_E8s_v5','Standard_E16s_v5')[$i % 4]
        Image            = if ($os -eq 'Windows') { 'MicrosoftWindowsServer:WindowsServer:2022-datacenter' } else { 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts' }
        Tags             = $res.tags
        PrivateIp        = "10.$($i % 5).$($i % 20).$($10 + $i)"
        PublicIp         = if ($i % 5 -eq 0) { "20.45.10.$i" } else { '' }
        Vnet             = 'vnet-hub-prod'
        Subnet           = @('snet-app','snet-data','snet-management')[$i % 3]
        BootDiagnostics  = ($i % 4 -ne 0)
        TimeCreated      = (Get-Date '2025-01-15').AddDays($i * 9).ToString('yyyy-MM-ddTHH:mm:ssZ')
        Status           = if ($i % 7 -eq 0) { 'deallocated' } else { 'running' }
        VCores           = $cores
        MemoryMB         = $memGb * 1024
        MemoryGB         = $memGb
        DiskGB           = $disk
    })
}

$vmScaleSets = @()
for ($i = 1; $i -le 4; $i++) {
    $sub = $subscriptions[$i % 3]
    $res = Add-Res $sub 'rg-apps-prod' ("vmss-api-{0}" -f $i) 'Microsoft.Compute/virtualMachineScaleSets' $regions[$i] 'Succeeded' (New-FakeTags -Owner 'api-platform' -Criticality 'high')
    $nodes = 1..(3 + $i) | ForEach-Object {
        [pscustomobject]@{
            Name         = "$($res.name)_$_"
            ComputerName = "$($res.name)-$_"
            Size         = @('Standard_D2s_v5','Standard_D4s_v5')[$_ % 2]
            PowerState   = if ($_ % 4 -eq 0) { 'deallocated' } else { 'running' }
        }
    }
    $vmScaleSets += [pscustomobject]@{
        Id                 = $res.id
        Name               = $res.name
        SubscriptionName   = $sub.Name
        ResourceGroup      = $res.resourceGroup
        Os                 = if ($i % 2) { 'Linux' } else { 'Windows' }
        Location           = $res.location
        Sku                = @('Standard_D2s_v5','Standard_D4s_v5')[$i % 2]
        OrchestrationMode  = if ($i % 2) { 'Flexible' } else { 'Uniform' }
        Capacity           = @($nodes).Count
        Image              = 'Canonical:UbuntuServer:22_04-lts'
        Vnet               = 'vnet-spoke-apps'
        Subnet             = 'snet-compute'
        TimeCreated        = (Get-Date '2025-02-01').AddDays($i * 13).ToString('yyyy-MM-ddTHH:mm:ssZ')
        Tags               = $res.tags
        Nodes              = @($nodes)
        ProvisioningState  = 'Succeeded'
    }
}

$relResources = @(
    Add-Res $subscriptions[2] 'rg-data-prod' 'sql-prod-orders-db' 'Microsoft.Sql/servers/databases' 'eastus2' 'Online' (New-FakeTags -Owner 'data-platform' -Criticality 'high')
    Add-Res $subscriptions[2] 'rg-data-prod' 'sql-prod-billing-db' 'Microsoft.Sql/servers/databases' 'eastus2' 'Online' (New-FakeTags -Owner 'finance' -Criticality 'high')
    Add-Res $subscriptions[2] 'rg-data-prod' 'sqlmi-core-prod' 'Microsoft.Sql/managedInstances' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'data-platform' -Criticality 'high')
    Add-Res $subscriptions[2] 'rg-data-prod' 'pg-flex-orders' 'Microsoft.DBforPostgreSQL/flexibleServers' 'westeurope' 'Ready' (New-FakeTags -Owner 'orders')
    Add-Res $subscriptions[2] 'rg-data-prod' 'mysql-flex-commerce' 'Microsoft.DBforMySQL/flexibleServers' 'brazilsouth' 'Ready' (New-FakeTags -Owner 'commerce')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'sqlvm-legacy-erp' 'Microsoft.SqlVirtualMachine/sqlVirtualMachines' 'eastus' 'Succeeded' (New-FakeTags -Owner 'erp' -Criticality 'medium')
    Add-Res $subscriptions[2] 'rg-data-prod' 'citus-analytics-prod' 'Microsoft.DBforPostgreSQL/serverGroupsv2' 'eastus2' 'Ready' (New-FakeTags -Owner 'analytics')
)

$relServices = @(
    [pscustomobject]@{ Type='Azure SQL Database'; Name='sql-prod-orders-db'; Id=$relResources[0].id; SubscriptionName=$subscriptions[2].Name; ResourceGroup='rg-data-prod'; Status='Online'; PricingTier='BusinessCritical Gen5'; MaxStorageGB=512; ElasticPool='orders-pool-prod'; Server='sql-prod-orders'; Tags=$relResources[0].tags },
    [pscustomobject]@{ Type='Azure SQL Database'; Name='sql-prod-billing-db'; Id=$relResources[1].id; SubscriptionName=$subscriptions[2].Name; ResourceGroup='rg-data-prod'; Status='Online'; PricingTier='GeneralPurpose Gen5'; MaxStorageGB=256; ElasticPool='billing-pool-prod'; Server='sql-prod-billing'; Tags=$relResources[1].tags },
    [pscustomobject]@{ Type='Azure SQL Managed Instance'; Name='sqlmi-core-prod'; Id=$relResources[2].id; SubscriptionName=$subscriptions[2].Name; ResourceGroup='rg-data-prod'; Status='Ready'; PricingTier='BusinessCritical'; VCores=16; DatabaseCount=8; MaxStorageGB=2048; AdminLogin='sqladmin'; Databases=@('core','ledger','audit','identity','events','jobs','ops','archive'); VnetIntegration='vnet-data-prod/snet-sqlmi'; Tags=$relResources[2].tags },
    [pscustomobject]@{ Type='Azure DB for PostgreSQL Flexible'; Name='pg-flex-orders'; Id=$relResources[3].id; SubscriptionName=$subscriptions[2].Name; ResourceGroup='rg-data-prod'; Status='Ready'; Version='16'; PricingTier='MemoryOptimized'; StorageGB=1024; AdminLogin='pgadmin'; HaMode='ZoneRedundant'; BackupRetentionDays=35; VnetIntegration='vnet-data-prod/snet-postgres'; Tags=$relResources[3].tags },
    [pscustomobject]@{ Type='Azure DB for MySQL Flexible'; Name='mysql-flex-commerce'; Id=$relResources[4].id; SubscriptionName=$subscriptions[2].Name; ResourceGroup='rg-data-prod'; Status='Ready'; Version='8.0'; PricingTier='GeneralPurpose'; StorageGB=512; AdminLogin='mysqladmin'; BackupRetentionDays=14; Tags=$relResources[4].tags },
    [pscustomobject]@{ Type='SQL Server on Azure VM (IaaS)'; Name='sqlvm-legacy-erp'; Id=$relResources[5].id; SubscriptionName=$subscriptions[1].Name; ResourceGroup='rg-apps-prod'; Status='running'; Os='Windows'; VmSize='Standard_E8s_v5'; SqlEdition='Enterprise'; LicenseType='AHUB'; ManagementMode='Full'; Image='SQL Server 2022 on Windows Server 2022'; Tags=$relResources[5].tags },
    [pscustomobject]@{ Type='Cosmos DB for PostgreSQL'; Name='citus-analytics-prod'; Id=$relResources[6].id; SubscriptionName=$subscriptions[2].Name; ResourceGroup='rg-data-prod'; Status='Ready'; Version='16'; NodeCount=5; Tags=$relResources[6].tags }
)

$nosqlResources = @(
    Add-Res $subscriptions[2] 'rg-data-prod' 'cosmos-orders-prod' 'Microsoft.DocumentDB/databaseAccounts' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'orders' -Criticality 'high')
    Add-Res $subscriptions[2] 'rg-data-prod' 'cosmos-catalog-mongo' 'Microsoft.DocumentDB/databaseAccounts' 'westeurope' 'Succeeded' (New-FakeTags -Owner 'catalog')
    Add-Res $subscriptions[3] 'rg-sandbox' 'cosmos-lab-table' 'Microsoft.DocumentDB/databaseAccounts' 'eastus' 'Succeeded' (New-FakeTags -Environment 'sandbox' -Owner 'lab' -Criticality 'low')
)
$cacheResources = @(
    Add-Res $subscriptions[1] 'rg-apps-prod' 'redis-commerce-prod' 'Microsoft.Cache/Redis' 'brazilsouth' 'Succeeded' (New-FakeTags -Owner 'commerce' -Criticality 'high')
    Add-Res $subscriptions[0] 'rg-platform-prod' 'redis-enterprise-shared' 'Microsoft.Cache/redisEnterprise' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'platform')
)
$analyticsResources = @(
    Add-Res $subscriptions[2] 'rg-data-prod' 'synw-prod-analytics' 'Microsoft.Synapse/workspaces' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'analytics')
    Add-Res $subscriptions[2] 'rg-data-prod' 'adx-prod-logs' 'Microsoft.Kusto/clusters' 'eastus2' 'Running' (New-FakeTags -Owner 'observability')
    Add-Res $subscriptions[2] 'rg-data-prod' 'dbw-prod-ml' 'Microsoft.Databricks/workspaces' 'westeurope' 'Succeeded' (New-FakeTags -Owner 'ml')
    Add-Res $subscriptions[2] 'rg-data-prod' 'as-finance-prod' 'Microsoft.AnalysisServices/servers' 'eastus' 'Succeeded' (New-FakeTags -Owner 'finance')
)
$tableResources = @(
    Add-Res $subscriptions[0] 'rg-platform-prod' 'stplatformauditprod' 'Microsoft.Storage/storageAccounts' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'platform')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'stappsessionprod' 'Microsoft.Storage/storageAccounts' 'brazilsouth' 'Succeeded' (New-FakeTags -Owner 'apps')
)

$dataServices = [pscustomobject]@{
    NoSQL = [pscustomobject]@{
        Total    = $nosqlResources.Count
        Counts   = [pscustomobject]@{ CosmosDb = $nosqlResources.Count }
        Services = @(
            New-ServiceRow 'Cosmos DB - NoSQL (Core)' $nosqlResources[0] @((New-Kv 'API' 'NoSQL (Core)'), (New-Kv 'Default consistency' 'Session'), (New-Kv 'Regions' 3), (New-Kv 'Multi-region writes' 'Yes'), (New-Kv 'Backup' 'Continuous'))
            New-ServiceRow 'Cosmos DB - MongoDB' $nosqlResources[1] @((New-Kv 'API' 'MongoDB'), (New-Kv 'Default consistency' 'BoundedStaleness'), (New-Kv 'Regions' 2), (New-Kv 'Free tier' 'No'))
            New-ServiceRow 'Cosmos DB - Table' $nosqlResources[2] @((New-Kv 'API' 'Table'), (New-Kv 'Default consistency' 'Session'), (New-Kv 'Regions' 1), (New-Kv 'Free tier' 'Yes'))
        )
    }
    Cache = [pscustomobject]@{
        Total    = $cacheResources.Count
        Counts   = [pscustomobject]@{ Redis = 1; RedisEnterprise = 1 }
        Services = @(
            New-ServiceRow 'Azure Cache for Redis' $cacheResources[0] @((New-Kv 'SKU' 'Premium P2'), (New-Kv 'Redis version' '6.0'), (New-Kv 'Shards' 2), (New-Kv 'Non-SSL port' 'No'))
            New-ServiceRow 'Azure Managed Redis (Enterprise)' $cacheResources[1] @((New-Kv 'SKU' 'Enterprise E10'), (New-Kv 'Capacity' 2), (New-Kv 'Min TLS' '1.2'))
        )
    }
    Analytics = [pscustomobject]@{
        Total    = $analyticsResources.Count
        Counts   = [pscustomobject]@{ Synapse = 1; DataExplorer = 1; Databricks = 1; AnalysisServices = 1; HDInsight = 0 }
        Services = @(
            New-ServiceRow 'Azure Synapse Analytics' $analyticsResources[0] @((New-Kv 'SQL admin' 'synadmin'), (New-Kv 'Managed RG' 'synw-managed-prod'))
            New-ServiceRow 'Azure Data Explorer' $analyticsResources[1] @((New-Kv 'SKU' 'Standard_D13_v2 x3'), (New-Kv 'URI' 'https://adx-prod-logs.eastus2.kusto.windows.net'))
            New-ServiceRow 'Azure Databricks' $analyticsResources[2] @((New-Kv 'SKU' 'premium'), (New-Kv 'Workspace URL' 'adb-1234567890.11.azuredatabricks.net'))
            New-ServiceRow 'Azure Analysis Services' $analyticsResources[3] @((New-Kv 'SKU' 'S2'), (New-Kv 'Tier' 'Standard'))
        )
    }
    TableStorage = [pscustomobject]@{
        Total    = $tableResources.Count
        Services = @(
            New-ServiceRow 'Azure Table Storage' $tableResources[0] @((New-Kv 'SKU' 'Standard_GRS'), (New-Kv 'Access tier' 'Hot'), (New-Kv 'HTTPS only' 'Yes'), (New-Kv 'Min TLS' '1.2'))
            New-ServiceRow 'Azure Table Storage' $tableResources[1] @((New-Kv 'SKU' 'Standard_LRS'), (New-Kv 'Access tier' 'Hot'), (New-Kv 'HTTPS only' 'Yes'), (New-Kv 'Min TLS' '1.2'))
        )
    }
}

$webResources = @(
    Add-Res $subscriptions[1] 'rg-apps-prod' 'app-commerce-prod' 'Microsoft.Web/sites' 'brazilsouth' 'Running' (New-FakeTags -Owner 'commerce' -Criticality 'high')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'app-portal-prod' 'Microsoft.Web/sites' 'eastus2' 'Running' (New-FakeTags -Owner 'portal')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'plan-apps-premium' 'Microsoft.Web/serverfarms' 'brazilsouth' 'Succeeded' (New-FakeTags -Owner 'platform')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'swa-marketing-prod' 'Microsoft.Web/staticSites' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'marketing')
)
$funcResources = @(
    Add-Res $subscriptions[1] 'rg-apps-prod' 'func-payment-events' 'Microsoft.Web/sites' 'eastus2' 'Running' (New-FakeTags -Owner 'payments')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'logic-order-fulfillment' 'Microsoft.Logic/workflows' 'eastus2' 'Enabled' (New-FakeTags -Owner 'orders')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'logic-standard-integrations' 'Microsoft.Web/sites' 'brazilsouth' 'Running' (New-FakeTags -Owner 'integration')
)
$containerResources = @(
    Add-Res $subscriptions[1] 'rg-apps-prod' 'ca-worker-orders' 'Microsoft.App/containerApps' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'orders')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'cae-prod-shared' 'Microsoft.App/managedEnvironments' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'platform')
    Add-Res $subscriptions[1] 'rg-apps-prod' 'aci-batch-reports' 'Microsoft.ContainerInstance/containerGroups' 'eastus' 'Succeeded' (New-FakeTags -Owner 'reports')
    Add-Res $subscriptions[0] 'rg-platform-prod' 'acrprodshared' 'Microsoft.ContainerRegistry/registries' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'platform')
)
$integrationResources = @(
    Add-Res $subscriptions[1] 'rg-apps-prod' 'apim-prod-shared' 'Microsoft.ApiManagement/service' 'brazilsouth' 'Succeeded' (New-FakeTags -Owner 'integration' -Criticality 'high')
)
$aksResources = @(
    Add-Res $subscriptions[1] 'rg-apps-prod' 'aks-prod-apps' 'Microsoft.ContainerService/managedClusters' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'platform' -Criticality 'high')
    Add-Res $subscriptions[3] 'rg-sandbox' 'aks-sandbox-lab' 'Microsoft.ContainerService/managedClusters' 'eastus' 'Succeeded' (New-FakeTags -Environment 'sandbox' -Owner 'lab' -Criticality 'low')
)

$applicationServices = [pscustomobject]@{
    Web = [pscustomobject]@{
        Total    = $webResources.Count
        Counts   = [pscustomobject]@{ WebApp = 2; WebAppContainers = 0; AppServicePlan = 1; Ase = 0; StaticWebApp = 1 }
        Services = @(
            New-ServiceRow 'Web App' $webResources[0] @((New-Kv 'Plan' 'plan-apps-premium'), (New-Kv 'Runtime' 'NODE|20-lts'), (New-Kv 'Default host' 'app-commerce-prod.azurewebsites.net'), (New-Kv 'HTTPS only' 'Yes'))
            New-ServiceRow 'Web App' $webResources[1] @((New-Kv 'Plan' 'plan-apps-premium'), (New-Kv 'Runtime' '.NET 8'), (New-Kv 'Default host' 'app-portal-prod.azurewebsites.net'), (New-Kv 'HTTPS only' 'Yes'))
            New-ServiceRow 'App Service Plan' $webResources[2] @((New-Kv 'SKU' 'P1v3'), (New-Kv 'Tier' 'PremiumV3'), (New-Kv 'Instances' 3), (New-Kv 'OS' 'Linux'))
            New-ServiceRow 'Static Web App' $webResources[3] @((New-Kv 'SKU' 'Standard'), (New-Kv 'Default host' 'happy-wave-123.azurestaticapps.net'), (New-Kv 'Repository' 'https://github.com/contoso/marketing'))
        )
    }
    Functions = [pscustomobject]@{
        Total    = $funcResources.Count
        Counts   = [pscustomobject]@{ FunctionApp = 1; LogicStandard = 1; LogicConsumption = 1 }
        Services = @(
            New-ServiceRow 'Function App' $funcResources[0] @((New-Kv 'Plan' 'Y1'), (New-Kv 'Runtime' 'PYTHON|3.11'), (New-Kv 'HTTPS only' 'Yes'))
            New-ServiceRow 'Logic App (Consumption)' $funcResources[1] @((New-Kv 'State' 'Enabled'))
            New-ServiceRow 'Logic App (Standard)' $funcResources[2] @((New-Kv 'Plan' 'plan-apps-premium'), (New-Kv 'Default host' 'logic-standard-integrations.azurewebsites.net'))
        )
    }
    Containers = [pscustomobject]@{
        Total    = $containerResources.Count
        Counts   = [pscustomobject]@{ ContainerApps = 1; ContainerAppsEnv = 1; ContainerInstances = 1; ContainerRegistry = 1; ServiceFabric = 0 }
        Services = @(
            New-ServiceRow 'Container Apps' $containerResources[0] @((New-Kv 'Environment' 'cae-prod-shared'), (New-Kv 'FQDN' 'ca-worker-orders.internal.azurecontainerapps.io'))
            New-ServiceRow 'Container Apps Environment' $containerResources[1] @((New-Kv 'Status' 'Succeeded'))
            New-ServiceRow 'Container Instances' $containerResources[2] @((New-Kv 'OS' 'Linux'), (New-Kv 'Containers' 2), (New-Kv 'IP' '10.2.8.40'))
            New-ServiceRow 'Container Registry' $containerResources[3] @((New-Kv 'SKU' 'Premium'), (New-Kv 'Login server' 'acrprodshared.azurecr.io'), (New-Kv 'Admin user' 'No'))
        )
    }
    Integration = [pscustomobject]@{
        Total    = $integrationResources.Count
        Counts   = [pscustomobject]@{ ApiManagement = 1 }
        Services = @(New-ServiceRow 'API Management' $integrationResources[0] @((New-Kv 'SKU' 'Premium'), (New-Kv 'Capacity' 2), (New-Kv 'Gateway' 'https://apim-prod-shared.azure-api.net'), (New-Kv 'VNet type' 'Internal')))
    }
    Aks = [pscustomobject]@{
        Total    = $aksResources.Count
        Services = @(
            New-ServiceRow 'Azure Kubernetes Service' $aksResources[0] @((New-Kv 'Kubernetes version' '1.30.7'), (New-Kv 'SKU tier' 'Standard'), (New-Kv 'Network plugin' 'azure'), (New-Kv 'Total nodes' 9), (New-Kv 'Pool - system' '3 x Standard_D4s_v5'), (New-Kv 'Pool - user' '6 x Standard_D8s_v5'))
            New-ServiceRow 'Azure Kubernetes Service' $aksResources[1] @((New-Kv 'Kubernetes version' '1.29.6'), (New-Kv 'SKU tier' 'Free'), (New-Kv 'Network plugin' 'kubenet'), (New-Kv 'Total nodes' 2))
        )
    }
}

$vnetResources = @()
for ($i = 1; $i -le 6; $i++) {
    $sub = $subscriptions[$i % $subscriptions.Count]
    $vnetResources += Add-Res $sub 'rg-network-prod' ("vnet-{0}-{1}" -f @('hub','apps','data','sandbox','shared','dmz')[$i-1], $i) 'Microsoft.Network/virtualNetworks' $regions[$i % $regions.Count] 'Succeeded' (New-FakeTags -Owner 'network')
}
$vnets = for ($i = 0; $i -lt $vnetResources.Count; $i++) {
    $v = $vnetResources[$i]
    [pscustomobject]@{
        SubscriptionName = $script:SubMap[$v.subscriptionId.ToLowerInvariant()]
        ResourceGroup    = $v.resourceGroup
        Name             = $v.name
        AddressSpace     = "10.$i.0.0/16"
        DnsServers       = if ($i % 2 -eq 0) { '10.0.0.4, 10.0.0.5' } else { '' }
        Id               = $v.id
        Tags             = $v.tags
        Subnets          = @(
            [pscustomobject]@{ SubnetName='snet-app'; Prefix="10.$i.1.0/24"; RouteTable='rt-shared-egress'; Routes=@([pscustomobject]@{ Prefix='0.0.0.0/0'; NextHop='AzureFirewall' }, [pscustomobject]@{ Prefix='10.0.0.0/8'; NextHop='VirtualNetworkGateway' }) },
            [pscustomobject]@{ SubnetName='snet-data'; Prefix="10.$i.2.0/24"; RouteTable='rt-private'; Routes=@([pscustomobject]@{ Prefix='0.0.0.0/0'; NextHop='None' }) },
            [pscustomobject]@{ SubnetName='snet-private-endpoints'; Prefix="10.$i.3.0/26"; RouteTable=''; Routes=@() }
        )
        Peerings         = @(
            [pscustomobject]@{ PeerName='to-hub'; RemoteVnet='vnet-hub-1'; State='Connected'; AllowGatewayTransit=($i -eq 0); UseRemoteGateways=($i -ne 0); AllowForwardedTraffic=$true }
        )
    }
}
$vnetGraphNodes = $vnets | ForEach-Object {
    [pscustomobject]@{ id = $_.Id; name = $_.Name; sub = $_.SubscriptionName; rg = $_.ResourceGroup }
}
$vnetGraphEdges = for ($i = 1; $i -lt $vnetGraphNodes.Count; $i++) {
    [pscustomobject]@{ From = $vnetGraphNodes[0].id; To = $vnetGraphNodes[$i].id; GatewayTransit = ($i -eq 1); UseRemoteGateways = ($i -gt 1); State = 'Connected' }
}

$lbResources = @(
    Add-Res $subscriptions[1] 'rg-network-prod' 'lb-internal-apps' 'Microsoft.Network/loadBalancers' 'eastus2' 'Succeeded' (New-FakeTags -Owner 'network')
    Add-Res $subscriptions[1] 'rg-network-prod' 'agw-prod-public' 'Microsoft.Network/applicationGateways' 'brazilsouth' 'Succeeded' (New-FakeTags -Owner 'network' -Criticality 'high')
    Add-Res $subscriptions[0] 'rg-network-prod' 'fd-global-prod' 'Microsoft.Cdn/profiles' 'global' 'Succeeded' (New-FakeTags -Owner 'network')
    Add-Res $subscriptions[0] 'rg-network-prod' 'tm-global-prod' 'Microsoft.Network/trafficManagerProfiles' 'global' 'Succeeded' (New-FakeTags -Owner 'network')
)
$loadBalancers = [pscustomobject]@{
    Total    = $lbResources.Count
    Counts   = [pscustomobject]@{ LoadBalancer = 1; AppGateway = 1; FrontDoor = 1; TrafficManager = 1 }
    Balancers = @(
        [pscustomobject]@{ SubscriptionName=$subscriptions[1].Name; ResourceGroup='rg-network-prod'; Name='lb-internal-apps'; Type='Azure Load Balancer'; Id=$lbResources[0].id; Tags=$lbResources[0].tags; Endpoints=@([pscustomobject]@{ Name='tcp-443'; Group='pool-apps'; Protocol='Tcp'; FrontendPort=443; BackendPort=443; Health='Healthy'; Servers=@('vm-linux-01','vm-linux-02','vm-linux-03') }) },
        [pscustomobject]@{ SubscriptionName=$subscriptions[1].Name; ResourceGroup='rg-network-prod'; Name='agw-prod-public'; Type='Application Gateway'; Id=$lbResources[1].id; Tags=$lbResources[1].tags; Endpoints=@([pscustomobject]@{ Name='https-listener'; Group='backend-commerce'; Protocol='Https'; FrontendPort=443; BackendPort=443; Health='Degraded'; Servers=@('app-commerce-prod.azurewebsites.net','app-portal-prod.azurewebsites.net') }) },
        [pscustomobject]@{ SubscriptionName=$subscriptions[0].Name; ResourceGroup='rg-network-prod'; Name='fd-global-prod'; Type='Azure Front Door'; Id=$lbResources[2].id; Tags=$lbResources[2].tags; Endpoints=@([pscustomobject]@{ Name='global-route'; Group='origin-group-prod'; Protocol='Https'; FrontendPort=443; BackendPort=443; Health='Healthy'; Servers=@('agw-prod-public.brazilsouth.cloudapp.azure.com') }) },
        [pscustomobject]@{ SubscriptionName=$subscriptions[0].Name; ResourceGroup='rg-network-prod'; Name='tm-global-prod'; Type='Traffic Manager'; Id=$lbResources[3].id; Tags=$lbResources[3].tags; Endpoints=@([pscustomobject]@{ Name='priority-prod'; Group='externalEndpoints'; Protocol='Https'; FrontendPort=443; BackendPort=443; Health='Healthy'; Servers=@('fd-global-prod.azurefd.net') }) }
    )
}

foreach ($extra in @(
    'Microsoft.Network/networkSecurityGroups',
    'Microsoft.Network/publicIPAddresses',
    'Microsoft.Network/privateEndpoints',
    'Microsoft.Network/routeTables',
    'Microsoft.KeyVault/vaults',
    'Microsoft.ManagedIdentity/userAssignedIdentities',
    'Microsoft.OperationalInsights/workspaces',
    'Microsoft.Insights/components',
    'Microsoft.Insights/dataCollectionRules',
    'Microsoft.Insights/dataCollectionEndpoints',
    'Microsoft.Insights/metricAlerts',
    'Microsoft.Portal/dashboards'
)) {
    for ($i = 1; $i -le 3; $i++) {
        $sub = $subscriptions[($i + $extra.Length) % $subscriptions.Count]
        $leaf = ($extra -split '/')[-1].ToLowerInvariant()
        Add-Res $sub $rgs[($i + 1) % $rgs.Count] "$leaf-$i" $extra $regions[($i + 2) % $regions.Count] | Out-Null
    }
}

$totalResources = $resourceList.Count
$bySub = $resourceList | Group-Object subscriptionId | ForEach-Object {
    [pscustomobject]@{ SubscriptionId = $_.Name; SubscriptionName = $script:SubMap[$_.Name.ToLowerInvariant()]; Count = $_.Count }
} | Sort-Object Count -Descending
$byType = $resourceList | Group-Object type | ForEach-Object {
    [pscustomobject]@{ Type = ($_.Name -split '/')[-1]; Count = $_.Count }
} | Sort-Object Count -Descending | Select-Object -First 10
$byRegion = $resourceList | Group-Object location | ForEach-Object {
    [pscustomobject]@{ Region = $_.Name; Count = $_.Count }
} | Sort-Object Count -Descending | Select-Object -First 8

$advisorRecommendations = @(
    [pscustomobject]@{ Category='Security'; Impact='High'; Problem='Enable MFA for privileged identities'; Solution='Require phishing-resistant MFA for all admin roles.'; Resource='tenant-root'; ResourceType='Microsoft Entra ID'; ResourceId='/providers/Microsoft.Management/managementGroups/contoso-root'; SubscriptionId=$subscriptions[0].Id },
    [pscustomobject]@{ Category='Cost'; Impact='High'; Problem='Right-size underutilized VMs'; Solution='Resize or stop low CPU virtual machines.'; Resource='vm-linux-07'; ResourceType='Microsoft.Compute/virtualMachines'; ResourceId=$vms[6].Id; SubscriptionId=$subscriptions[3].Id },
    [pscustomobject]@{ Category='Reliability'; Impact='High'; Problem='Enable zone redundancy for critical databases'; Solution='Move critical tiers to zone redundant configuration.'; Resource='sqlmi-core-prod'; ResourceType='Microsoft.Sql/managedInstances'; ResourceId=$relResources[2].id; SubscriptionId=$subscriptions[2].Id },
    [pscustomobject]@{ Category='Performance'; Impact='Medium'; Problem='Increase App Gateway instance count'; Solution='Configure autoscale minimum capacity above one instance.'; Resource='agw-prod-public'; ResourceType='Microsoft.Network/applicationGateways'; ResourceId=$lbResources[1].id; SubscriptionId=$subscriptions[1].Id },
    [pscustomobject]@{ Category='OperationalExcellence'; Impact='Medium'; Problem='Add resource locks to production shared services'; Solution='Apply CanNotDelete locks to shared platform resources.'; Resource='rg-platform-prod'; ResourceType='Microsoft.Resources/resourceGroups'; ResourceId="/subscriptions/$($subscriptions[0].Id)/resourceGroups/rg-platform-prod"; SubscriptionId=$subscriptions[0].Id }
)
foreach ($i in 1..14) {
    $res = $resourceList[($i * 5) % $resourceList.Count]
    $advisorRecommendations += [pscustomobject]@{
        Category       = @('Security','Reliability','Cost','Performance','OperationalExcellence')[$i % 5]
        Impact         = @('High','Medium','Low')[$i % 3]
        Problem        = "Synthetic advisor recommendation $i for $($res.name)"
        Solution       = "Review $($res.type) configuration and apply the recommended baseline."
        Resource       = $res.name
        ResourceType   = $res.type
        ResourceId     = $res.id
        SubscriptionId = $res.subscriptionId
    }
}

$secItems = @(
    [pscustomobject]@{ Severity='Critical'; Title='Public management ports exposed'; ResourceType='microsoft.network/networksecuritygroups'; Count=7; Resources=@($resourceList | Where-Object type -like '*networksecuritygroups' | Select-Object -First 5 | ForEach-Object { To-FindingResource $_ }) },
    [pscustomobject]@{ Severity='High'; Title='Key Vaults without purge protection'; ResourceType='microsoft.keyvault/vaults'; Count=5; Resources=@($resourceList | Where-Object type -like '*keyvault*' | Select-Object -First 3 | ForEach-Object { To-FindingResource $_ }) },
    [pscustomobject]@{ Severity='Medium'; Title='Storage accounts allowing public network access'; ResourceType='microsoft.storage/storageaccounts'; Count=4; Resources=@($tableResources | ForEach-Object { To-FindingResource $_ }) },
    [pscustomobject]@{ Severity='Low'; Title='Missing required ownership tag'; ResourceType='multiple'; Count=11; Resources=@($resourceList | Select-Object -First 8 | ForEach-Object { To-FindingResource $_ }) }
)
$costItems = @(
    [pscustomobject]@{ Title='Stopped VMs with attached premium disks'; ResourceType='microsoft.compute/virtualmachines'; Note='Deallocated compute still has paid storage attached'; Count=3; Resources=@($vms | Where-Object Status -eq 'deallocated' | Select-Object -First 3 | ForEach-Object { [pscustomobject]@{ Name=$_.Name; Type='microsoft.compute/virtualmachines'; ResourceGroup=$_.ResourceGroup; SubscriptionName=$_.SubscriptionName; Id=$_.Id } }) },
    [pscustomobject]@{ Title='Unattached public IP addresses'; ResourceType='microsoft.network/publicipaddresses'; Note='Public IPs not associated with a NIC or load balancer'; Count=6; Resources=@($resourceList | Where-Object type -like '*publicipaddresses' | Select-Object -First 5 | ForEach-Object { To-FindingResource $_ }) },
    [pscustomobject]@{ Title='Idle App Service Plans'; ResourceType='microsoft.web/serverfarms'; Note='Plans with no deployed apps or low utilization'; Count=2; Resources=@($webResources | Where-Object type -like '*serverfarms' | ForEach-Object { To-FindingResource $_ }) },
    [pscustomobject]@{ Title='Oversized Log Analytics retention'; ResourceType='microsoft.operationalinsights/workspaces'; Note='Retention above target baseline for non-critical workspaces'; Count=4; Resources=@($resourceList | Where-Object type -like '*workspaces' | Select-Object -First 4 | ForEach-Object { To-FindingResource $_ }) }
)

$diagResources = @($resourceList | Select-Object -First 55 | ForEach-Object -Begin { $idx = 0 } -Process {
    $idx++
    $enabled = ($idx % 4 -ne 0)
    [pscustomobject]@{
        SubscriptionName = $script:SubMap[$_.subscriptionId.ToLowerInvariant()]
        ResourceGroup    = $_.resourceGroup
        Name             = $_.name
        Type             = $_.type
        Enabled          = $enabled
        Destinations     = if ($enabled) { @('Log Analytics', 'Storage') } else { @() }
        Id               = $_.id
        Tags             = $_.tags
        Settings         = if ($enabled) {
            @([pscustomobject]@{
                Name            = 'send-to-law'
                LogAnalytics    = 'law-prod-shared'
                Storage         = 'stplatformauditprod'
                EventHub        = ''
                ThirdParty      = ''
                LogsEnabled     = @('AuditEvent','Administrative','Security')
                LogsDisabled    = @('Verbose')
                MetricsEnabled  = @('AllMetrics')
                MetricsDisabled = @()
            })
        } else { @() }
    }
})
$diagEnabled = @($diagResources | Where-Object Enabled).Count

$dcrs = @()
for ($i = 1; $i -le 5; $i++) {
    $dcrs += [pscustomobject]@{
        SubscriptionName = $subscriptions[0].Name
        ResourceGroup    = 'rg-observability'
        Name             = "dcr-prod-$i"
        Kind             = if ($i % 2) { 'Linux' } else { 'Windows' }
        Location         = $regions[$i % $regions.Count]
        MachineCount     = 3 + $i
        Id               = New-FakeId $subscriptions[0].Id 'rg-observability' 'Microsoft.Insights/dataCollectionRules' "dcr-prod-$i"
        Tags             = New-FakeTags -Owner 'observability'
        Destinations     = @([pscustomobject]@{ Type='LogAnalytics'; Name='law-prod-shared' }, [pscustomobject]@{ Type='Storage'; Name='stplatformauditprod' })
        Streams          = @('Microsoft-Perf','Microsoft-Syslog','Microsoft-Event')
        DataSourceKinds  = @('performanceCounters','syslog','windowsEventLogs')
    }
}
$dces = 1..3 | ForEach-Object {
    [pscustomobject]@{
        SubscriptionName = $subscriptions[0].Name
        ResourceGroup    = 'rg-observability'
        Name             = "dce-prod-$_"
        Location         = $regions[$_]
        Id               = New-FakeId $subscriptions[0].Id 'rg-observability' 'Microsoft.Insights/dataCollectionEndpoints' "dce-prod-$_"
        Tags             = New-FakeTags -Owner 'observability'
    }
}
$machines = @($vms | Select-Object -First 14 | ForEach-Object -Begin { $idx = 0 } -Process {
    $idx++
    [pscustomobject]@{
        Name             = $_.Name
        Kind             = 'VM'
        SubscriptionName = $_.SubscriptionName
        ResourceGroup    = $_.ResourceGroup
        Location         = $_.Location
        AmaInstalled     = ($idx % 5 -ne 0)
        AmaVersion       = if ($idx % 5 -ne 0) { '1.31.1' } else { '' }
        Dcrs             = @("dcr-prod-$((($idx - 1) % 5) + 1)")
        Dces             = @("dce-prod-$((($idx - 1) % 3) + 1)")
        Id               = $_.Id
    }
})
$machineNodes = $machines | ForEach-Object { [pscustomobject]@{ id=$_.Id; name=$_.Name; sub=$_.SubscriptionName; rg=$_.ResourceGroup } }
$dcrNodes = $dcrs | ForEach-Object { [pscustomobject]@{ id=$_.Id; name=$_.Name } }
$destNodes = @(
    [pscustomobject]@{ id='dest-law-prod-shared'; name='law-prod-shared' },
    [pscustomobject]@{ id='dest-stplatformauditprod'; name='stplatformauditprod' }
)

$workspaces = @(
    [pscustomobject]@{ SubscriptionName=$subscriptions[0].Name; ResourceGroup='rg-observability'; Name='law-prod-shared'; UsedByAppInsights=$true; Retention=90; Sku='PerGB2018'; DailyQuotaGb=$null; ExportToStorage=$true; Location='eastus2'; IngestionAccess='Enabled'; Id=New-FakeId $subscriptions[0].Id 'rg-observability' 'Microsoft.OperationalInsights/workspaces' 'law-prod-shared'; Tags=New-FakeTags -Owner 'observability' },
    [pscustomobject]@{ SubscriptionName=$subscriptions[1].Name; ResourceGroup='rg-apps-prod'; Name='law-apps-prod'; UsedByAppInsights=$true; Retention=30; Sku='PerGB2018'; DailyQuotaGb=25; ExportToStorage=$false; Location='brazilsouth'; IngestionAccess='Enabled'; Id=New-FakeId $subscriptions[1].Id 'rg-apps-prod' 'Microsoft.OperationalInsights/workspaces' 'law-apps-prod'; Tags=New-FakeTags -Owner 'apps' },
    [pscustomobject]@{ SubscriptionName=$subscriptions[3].Name; ResourceGroup='rg-sandbox'; Name='law-sandbox'; UsedByAppInsights=$false; Retention=14; Sku='PerGB2018'; DailyQuotaGb=5; ExportToStorage=$false; Location='eastus'; IngestionAccess='Enabled'; Id=New-FakeId $subscriptions[3].Id 'rg-sandbox' 'Microsoft.OperationalInsights/workspaces' 'law-sandbox'; Tags=New-FakeTags -Environment 'sandbox' -Owner 'lab' }
)

$policyItems = @(
    [pscustomobject]@{ Name='Deny public IP on NICs'; Type='Policy'; Scope='/providers/Microsoft.Management/managementGroups/contoso-platform'; Evaluated=$true; Compliant=$false; CompliancePercent=73; Id='/providers/Microsoft.Authorization/policyAssignments/deny-public-ip'; Definition='Deny network interfaces with public IPs'; EnforcementMode='Default'; IdentityType='SystemAssigned'; Members=@(); Parameters=@([pscustomobject]@{ Name='effect'; Value='Deny' }); CompliantCount=180; NonCompliantCount=67 },
    [pscustomobject]@{ Name='Deploy diagnostics to Log Analytics'; Type='Initiative'; Scope='/providers/Microsoft.Management/managementGroups/contoso-root'; Evaluated=$true; Compliant=$false; CompliancePercent=68; Id='/providers/Microsoft.Authorization/policyAssignments/deploy-diagnostics'; Definition='Azure Monitor baseline'; EnforcementMode='Default'; IdentityType='SystemAssigned'; Members=@('Deploy diagnostic settings','Enable activity log export','Configure VM insights'); Parameters=@([pscustomobject]@{ Name='workspaceId'; Value='law-prod-shared' }); CompliantCount=220; NonCompliantCount=104 },
    [pscustomobject]@{ Name='Require owner and costCenter tags'; Type='Policy'; Scope='/providers/Microsoft.Management/managementGroups/contoso-root'; Evaluated=$true; Compliant=$true; CompliancePercent=91; Id='/providers/Microsoft.Authorization/policyAssignments/require-tags'; Definition='Require tags on resources'; EnforcementMode='Default'; IdentityType='None'; Members=@(); Parameters=@([pscustomobject]@{ Name='tagNames'; Value='owner,costCenter' }); CompliantCount=317; NonCompliantCount=31 }
)
$policyRemItems = @(
    [pscustomobject]@{ Policy='Deploy diagnostics to Log Analytics'; Assignment='deploy-diagnostics'; Scope='/providers/Microsoft.Management/managementGroups/contoso-root'; ResourceCount=104; Resources=@('vm-linux-04','redis-commerce-prod','cosmos-catalog-mongo','app-portal-prod','agw-prod-public') },
    [pscustomobject]@{ Policy='Configure Defender plans'; Assignment='defender-baseline'; Scope='/subscriptions/44444444-4444-4444-4444-444444444444'; ResourceCount=12; Resources=@('Contoso Sandbox','law-sandbox','aks-sandbox-lab') }
)

$defenderSubs = foreach ($s in $subscriptions) {
    [pscustomobject]@{
        Subscription  = $s.Name
        StandardCount = if ($s.Name -like '*Sandbox') { 3 } else { 8 }
        FreeCount     = if ($s.Name -like '*Sandbox') { 5 } else { 1 }
        Total         = 9
        Plans         = @(
            [pscustomobject]@{ Name='VirtualMachines'; SubPlan='P2'; Active=$true; Partial=$false; Extensions=@([pscustomobject]@{ Name='MDE'; Enabled=$true }, [pscustomobject]@{ Name='AgentlessScanning'; Enabled=$true }) },
            [pscustomobject]@{ Name='StorageAccounts'; SubPlan='DefenderForStorageV2'; Active=$true; Partial=($s.Name -like '*Sandbox'); Extensions=@([pscustomobject]@{ Name='MalwareScanning'; Enabled=($s.Name -notlike '*Sandbox') }, [pscustomobject]@{ Name='SensitiveDataDiscovery'; Enabled=$true }) },
            [pscustomobject]@{ Name='KeyVaults'; SubPlan=''; Active=($s.Name -notlike '*Sandbox'); Partial=$false; Extensions=@() }
        )
    }
}
$defRecs = 1..12 | ForEach-Object {
    $res = $resourceList[($_ * 7) % $resourceList.Count]
    [pscustomobject]@{
        RiskLevel   = @('Critical','High','Medium','Low')[$_ % 4]
        Title       = @('Resolve endpoint protection health issues','Encrypt data at rest with customer-managed keys','Restrict public network access','Enable vulnerability assessment')[$_ % 4]
        Resource    = $res.name
        Status      = if ($_ % 5 -eq 0) { 'Healthy' } else { 'Unhealthy' }
        Scope       = $script:SubMap[$res.subscriptionId.ToLowerInvariant()]
        LastChange  = (Get-Date '2026-05-01').AddDays($_).ToString('yyyy-MM-dd')
        Remediation = '<ol><li>Review the affected resource.</li><li>Apply the recommended secure configuration.</li></ol>'
        Description = 'Synthetic Defender recommendation generated for layout validation.'
        RiskFactors = @('Internet exposure', 'Sensitive data', 'Privileged access') | Select-Object -First (($_ % 3) + 1)
        ResourceId  = $res.id
    }
}

$mgRows = @(
    [pscustomobject]@{ Id='contoso-root'; Name='Contoso Root'; Parent='' },
    [pscustomobject]@{ Id='contoso-platform'; Name='Platform'; Parent='contoso-root' },
    [pscustomobject]@{ Id='contoso-workloads'; Name='Workloads'; Parent='contoso-root' },
    [pscustomobject]@{ Id='contoso-sandbox'; Name='Sandbox'; Parent='contoso-root' }
)
$subRows = @(
    [pscustomobject]@{ Id=$subscriptions[0].Id; Name=$subscriptions[0].Name; ManagementGroup='contoso-platform' },
    [pscustomobject]@{ Id=$subscriptions[1].Id; Name=$subscriptions[1].Name; ManagementGroup='contoso-workloads' },
    [pscustomobject]@{ Id=$subscriptions[2].Id; Name=$subscriptions[2].Name; ManagementGroup='contoso-workloads' },
    [pscustomobject]@{ Id=$subscriptions[3].Id; Name=$subscriptions[3].Name; ManagementGroup='contoso-sandbox' }
)

$reportData = [pscustomobject]@{
    metadata = [pscustomobject]@{
        GeneratedAt   = $GeneratedAt.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'
        TenantDomain  = 'contoso.example'
        Account       = 'aer.fixture@contoso.example'
        DurationMs    = 42137
        ModuleVersion = "$ModuleVersion-sample"
    }
    inventory = [pscustomobject]@{
        ManagementGroups    = $mgRows.Count
        Subscriptions       = $subscriptions.Count
        TotalResourceGroups = $rgs.Count
        TotalResources      = $totalResources
        BySubscription      = @($bySub)
        ByType              = @($byType)
        ByRegion            = @($byRegion)
        SubscriptionMap     = $script:SubMap
        ResourceList        = @($resourceList)
    }
    security = [pscustomobject]@{
        TotalGaps = [int](($secItems | Measure-Object Count -Sum).Sum)
        Items     = @($secItems)
    }
    cost = [pscustomobject]@{
        TotalWastedResources = [int](($costItems | Measure-Object Count -Sum).Sum)
        Items                = @($costItems)
    }
    advisor = [pscustomobject]@{
        TotalRecommendations = $advisorRecommendations.Count
        HighImpactCount      = @($advisorRecommendations | Where-Object Impact -eq 'High').Count
        ByCategory           = @('Security','Reliability','Cost','Performance','OperationalExcellence') | ForEach-Object {
            $cat = $_; [pscustomobject]@{ Category=$cat; Count=@($advisorRecommendations | Where-Object Category -eq $cat).Count }
        }
        Recommendations      = @($advisorRecommendations)
    }
    structure = [pscustomobject]@{
        ManagementGroups = @($mgRows)
        Subscriptions    = @($subRows)
    }
    virtualMachines = [pscustomobject]@{
        TotalVMs      = $vms.Count
        LinuxVMs      = @($vms | Where-Object Os -eq 'Linux').Count
        WindowsVMs    = @($vms | Where-Object Os -eq 'Windows').Count
        TotalvCores   = [int](($vms | Measure-Object VCores -Sum).Sum)
        TotalMemoryGB = [int](($vms | Measure-Object MemoryGB -Sum).Sum)
        TotalDiskGB   = [int](($vms | Measure-Object DiskGB -Sum).Sum)
        VirtualMachines = @($vms)
    }
    virtualMachineScaleSets = [pscustomobject]@{
        TotalVMSS      = $vmScaleSets.Count
        LinuxVMSS      = @($vmScaleSets | Where-Object Os -eq 'Linux').Count
        WindowsVMSS    = @($vmScaleSets | Where-Object Os -eq 'Windows').Count
        UniformVMSS    = @($vmScaleSets | Where-Object OrchestrationMode -eq 'Uniform').Count
        FlexibleVMSS   = @($vmScaleSets | Where-Object OrchestrationMode -eq 'Flexible').Count
        TotalInstances = [int](($vmScaleSets | Measure-Object Capacity -Sum).Sum)
        ScaleSets      = @($vmScaleSets)
    }
    databases = [pscustomobject]@{
        TotalServices  = $relServices.Count + $nosqlResources.Count + $cacheResources.Count + $analyticsResources.Count
        Relational     = $relServices.Count
        NoSQL          = $nosqlResources.Count
        Cache          = $cacheResources.Count
        Analytics      = $analyticsResources.Count
        DistinctTypes  = 11
        TableStorage   = $tableResources.Count
        ByCategory     = @(
            [pscustomobject]@{ Category='Relational'; Count=$relServices.Count },
            [pscustomobject]@{ Category='NoSQL'; Count=$nosqlResources.Count },
            [pscustomobject]@{ Category='Cache'; Count=$cacheResources.Count },
            [pscustomobject]@{ Category='Analytics'; Count=$analyticsResources.Count }
        )
        ByType         = @(
            [pscustomobject]@{ Label='Azure SQL Database'; Category='Relational'; Count=2 },
            [pscustomobject]@{ Label='Cosmos DB'; Category='NoSQL'; Count=3 },
            [pscustomobject]@{ Label='Azure Cache for Redis'; Category='Cache'; Count=2 },
            [pscustomobject]@{ Label='Azure Synapse Analytics'; Category='Analytics'; Count=1 },
            [pscustomobject]@{ Label='Azure Data Explorer'; Category='Analytics'; Count=1 },
            [pscustomobject]@{ Label='Azure Databricks'; Category='Analytics'; Count=1 }
        )
        ByLocation     = @($resourceList | Where-Object { $_.type -match 'sql|documentdb|cache|synapse|kusto|databricks|analysisservices' } | Group-Object location | ForEach-Object { [pscustomobject]@{ Region=$_.Name; Count=$_.Count } })
        CosmosFamilies = @([pscustomobject]@{ Api='NoSQL (Core)'; Count=1 }, [pscustomobject]@{ Api='MongoDB'; Count=1 }, [pscustomobject]@{ Api='Table'; Count=1 })
        RedisFamilies  = @([pscustomobject]@{ Tier='Premium'; Count=1 }, [pscustomobject]@{ Tier='Enterprise'; Count=1 })
    }
    relationalDatabases = [pscustomobject]@{
        TotalRelational = $relServices.Count
        Counts          = [pscustomobject]@{ SqlDatabase=2; SqlManagedInstance=1; SqlOnVm=1; PostgresFlexible=1; MysqlFlexible=1; CosmosPostgres=1 }
        Services        = @($relServices)
    }
    dataServices = $dataServices
    applications = [pscustomobject]@{
        TotalServices = $webResources.Count + $funcResources.Count + $containerResources.Count + $integrationResources.Count + $aksResources.Count
        Web           = $webResources.Count
        Functions     = $funcResources.Count
        Containers    = $containerResources.Count
        Integration   = $integrationResources.Count
        Aks           = $aksResources.Count
        DistinctTypes = 12
        ByCategory    = @(
            [pscustomobject]@{ Category='Web / App Service'; Count=$webResources.Count },
            [pscustomobject]@{ Category='Functions & Logic'; Count=$funcResources.Count },
            [pscustomobject]@{ Category='Containers'; Count=$containerResources.Count },
            [pscustomobject]@{ Category='API & Integration'; Count=$integrationResources.Count },
            [pscustomobject]@{ Category='AKS'; Count=$aksResources.Count }
        )
        ByType        = @(
            [pscustomobject]@{ Label='Web App'; Count=2 },
            [pscustomobject]@{ Label='App Service Plan'; Count=1 },
            [pscustomobject]@{ Label='Function App'; Count=1 },
            [pscustomobject]@{ Label='Container Apps'; Count=1 },
            [pscustomobject]@{ Label='Azure Kubernetes Service'; Count=2 }
        )
        ByLocation    = @($resourceList | Where-Object { $_.type -match 'web|app/container|containerinstance|containerregistry|apimanagement|containerservice' } | Group-Object location | ForEach-Object { [pscustomobject]@{ Region=$_.Name; Count=$_.Count } })
        AksByVersion  = @([pscustomobject]@{ Version='1.30.7'; Count=1 }, [pscustomobject]@{ Version='1.29.6'; Count=1 })
        PlansByTier   = @([pscustomobject]@{ Tier='PremiumV3'; Count=1 }, [pscustomobject]@{ Tier='Consumption'; Count=1 })
    }
    applicationServices = $applicationServices
    network = [pscustomobject]@{
        Counts = [pscustomobject]@{
            Vnet=$vnetResources.Count; Subnets=18; Peerings=$vnetGraphEdges.Count; Gateways=2; ExpressRoute=1; PrivateEndpoints=7; AppGateway=1; FrontDoor=1; TrafficManager=1; LoadBalancer=1; AzureFirewall=1; Nsg=6; PublicIp=9; RouteTables=4; DdosPlans=1
        }
        IpUsage   = [pscustomobject]@{ Occupied=823; Free=5741; PercentUsed=13 }
        Dns       = [pscustomobject]@{ Public=8; Private=11 }
        Balancers = @([pscustomobject]@{ Type='Load Balancer'; Count=1 }, [pscustomobject]@{ Type='Application Gateway'; Count=1 }, [pscustomobject]@{ Type='Front Door'; Count=1 }, [pscustomobject]@{ Type='Traffic Manager'; Count=1 })
    }
    vnets = [pscustomobject]@{
        Vnets = @($vnets)
        Graph = [pscustomobject]@{ Nodes=@($vnetGraphNodes); Edges=@($vnetGraphEdges) }
    }
    loadBalancers = $loadBalancers
    observability = [pscustomobject]@{
        Total = 34
        SubscriptionsEvaluated = $subscriptions.Count
        Workspaces = $workspaces.Count
        AmaCoverage = [pscustomobject]@{ Machines=$machines.Count; WithAma=@($machines | Where-Object AmaInstalled).Count; Percent=[int]([math]::Round((@($machines | Where-Object AmaInstalled).Count / $machines.Count) * 100)) }
        AppInsightsCoverage = [pscustomobject]@{ Apps=8; Covered=6; Percent=75 }
        Counts = [pscustomobject]@{ AppInsights=6; DataCollectionRules=$dcrs.Count; DataCollectionEndpoints=$dces.Count; ActionGroups=4; AlertRules=12; Workbooks=5; Dashboards=3; Grafana=1; AutomationAccounts=2 }
    }
    diagnosticSettings = [pscustomobject]@{
        Summary = [pscustomobject]@{ TotalResources=$totalResources; Evaluated=$diagResources.Count; Enabled=$diagEnabled; Percent=[int]([math]::Round(($diagEnabled / $diagResources.Count) * 100)) }
        CoverageBySubscription = @($diagResources | Group-Object SubscriptionName | ForEach-Object { $enabled = @($_.Group | Where-Object Enabled).Count; [pscustomobject]@{ Subscription=$_.Name; Total=$_.Count; Covered=$enabled; Percent=[int]([math]::Round(($enabled / $_.Count) * 100)) } })
        TopTypesWithoutDiag = @($diagResources | Where-Object { -not $_.Enabled } | Group-Object Type | ForEach-Object { [pscustomobject]@{ Type=($_.Name -split '/')[-1]; Count=$_.Count } } | Sort-Object Count -Descending)
        Resources = @($diagResources)
    }
    dataCollection = [pscustomobject]@{
        Counts = [pscustomobject]@{ Dcr=$dcrs.Count; Dce=$dces.Count; Machines=$machines.Count; MachinesWithAma=@($machines | Where-Object AmaInstalled).Count; Associations=$machines.Count }
        Dcrs = @($dcrs)
        Dces = @($dces)
        Machines = @($machines)
        Graph = [pscustomobject]@{
            Vms = @($machineNodes)
            Dcrs = @($dcrNodes)
            Dests = @($destNodes)
            VmDcrEdges = @($machines | ForEach-Object { [pscustomobject]@{ From=$_.Id; To=($dcrs | Where-Object Name -eq $_.Dcrs[0]).Id } })
            DcrDestEdges = @($dcrs | ForEach-Object {
                [pscustomobject]@{ From=$_.Id; To='dest-law-prod-shared' }
                [pscustomobject]@{ From=$_.Id; To='dest-stplatformauditprod' }
            })
        }
    }
    obsInventory = [pscustomobject]@{
        Counts = [pscustomobject]@{ AppInsights=6; Workspaces=$workspaces.Count }
        Workspaces = @($workspaces)
    }
    policy = [pscustomobject]@{
        Compliance = [pscustomobject]@{ OverallPercent=78; Compliant=717; NonCompliant=202; Conflict=6; Evaluated=925 }
        Assignments = [pscustomobject]@{ Policy=2; Initiative=1; Total=3 }
        PendingRemediation = 116
        EffectsByType = @([pscustomobject]@{ Effect='Deny'; Count=8 }, [pscustomobject]@{ Effect='Audit'; Count=11 }, [pscustomobject]@{ Effect='DeployIfNotExists'; Count=9 }, [pscustomobject]@{ Effect='Modify'; Count=3 })
        Items = @($policyItems)
        Exemptions = @(
            [pscustomobject]@{ Name='temporary-sandbox-public-ip'; Assignment='Deny public IP on NICs'; Scope='/subscriptions/44444444-4444-4444-4444-444444444444'; Category='Waiver'; CreatedBy='cloud-admin@contoso.example'; CreatedByType='User'; ExpiresOn='2026-07-31'; Expired=$false; Id='/providers/Microsoft.Authorization/policyExemptions/temporary-sandbox-public-ip'; Description='Lab exception during migration.'; ReferenceIds=@('deny-public-ip'); AppliesTo=@('Deny public IP on NICs'); ResourceSelectors=@('rg-sandbox') },
            [pscustomobject]@{ Name='legacy-erp-diagnostics'; Assignment='Deploy diagnostics to Log Analytics'; Scope='/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-apps-prod'; Category='Mitigated'; CreatedBy='platform@contoso.example'; CreatedByType='User'; ExpiresOn=''; Expired=$false; Id='/providers/Microsoft.Authorization/policyExemptions/legacy-erp-diagnostics'; Description='Legacy agent is being replaced by AMA.'; ReferenceIds=@('deploy-diagnostic-settings'); AppliesTo=@('sqlvm-legacy-erp'); ResourceSelectors=@() }
        )
        Remediation = [pscustomobject]@{
            PoliciesToRemediate = $policyRemItems.Count
            ResourcesToRemediate = 116
            Items = @($policyRemItems)
            Tasks = @(
                [pscustomobject]@{ Name='remediate-diagnostics-prod'; Assignment='deploy-diagnostics'; Scope='/providers/Microsoft.Management/managementGroups/contoso-root'; State='InProgress'; Succeeded=42; Failed=3; Total=91; CreatedOn='2026-05-20' },
                [pscustomobject]@{ Name='remediate-defender-sandbox'; Assignment='defender-baseline'; Scope='/subscriptions/44444444-4444-4444-4444-444444444444'; State='Succeeded'; Succeeded=12; Failed=0; Total=12; CreatedOn='2026-05-18' }
            )
        }
    }
    defender = [pscustomobject]@{
        Summary = [pscustomobject]@{ Total=128; Unhealthy=41; Healthy=79; NotApplicable=8 }
        Subscriptions = @($defenderSubs)
        SeverityCounts = [pscustomobject]@{
            Critical = @($defRecs | Where-Object RiskLevel -eq 'Critical').Count
            High     = @($defRecs | Where-Object RiskLevel -eq 'High').Count
            Medium   = @($defRecs | Where-Object RiskLevel -eq 'Medium').Count
            Low      = @($defRecs | Where-Object RiskLevel -eq 'Low').Count
        }
        Recommendations = @($defRecs)
    }
    collectionErrors = @()
}

    return $reportData
}
