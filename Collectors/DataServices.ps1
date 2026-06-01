function Get-AerDataServices {
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
    $arg = { param($q) try { Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $q } catch { Write-Warning "[DataServices] $($_.Exception.Message)"; @() } }

    function New-Service($type, $r, $details) {
        [pscustomobject]@{
            Type = $type; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            Details = @($details)
        }
    }

    # ════════════════════════════ NoSQL — Cosmos DB ═════════════════════════
    $nosql = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.documentdb/databaseaccounts'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          acctKind = tostring(kind),
          consistency = tostring(properties.consistencyPolicy.defaultConsistencyLevel),
          regionCount = toint(array_length(properties.locations)),
          multiWrite = tobool(properties.enableMultipleWriteLocations),
          freeTier = tobool(properties.enableFreeTier),
          backupType = tostring(properties.backupPolicy.type),
          capabilities = properties.capabilities,
          vnetRules = properties.virtualNetworkRules,
          tags
'@)) {
        $caps = @($r.capabilities | ForEach-Object { $_.name })
        $cosmosVnet = (@($r.vnetRules | ForEach-Object { Get-AerSubnetLabel $_.id } | Where-Object { $_ }) -join ', ')
        $api = 'NoSQL (Core)'
        if     ($r.acctKind -match 'MongoDB')      { $api = 'MongoDB' }
        elseif ($caps -contains 'EnableCassandra') { $api = 'Cassandra' }
        elseif ($caps -contains 'EnableGremlin')   { $api = 'Gremlin' }
        elseif ($caps -contains 'EnableTable')     { $api = 'Table' }
        elseif ($caps -contains 'EnableMongo')     { $api = 'MongoDB' }
        $serverless = if ($caps -contains 'EnableServerless') { 'Yes' } else { 'No' }
        $nosql.Add((New-Service "Cosmos DB · $api" $r @(
            [pscustomobject]@{ label = 'API';                 value = $api }
            [pscustomobject]@{ label = 'Status';              value = $r.status }
            [pscustomobject]@{ label = 'Default consistency'; value = $r.consistency }
            [pscustomobject]@{ label = 'Regions';             value = $r.regionCount }
            [pscustomobject]@{ label = 'Multi-region writes'; value = (YesNo $r.multiWrite) }
            [pscustomobject]@{ label = 'Free tier';           value = (YesNo $r.freeTier) }
            [pscustomobject]@{ label = 'Serverless';          value = $serverless }
            [pscustomobject]@{ label = 'Backup';              value = $r.backupType }
            [pscustomobject]@{ label = 'VNet integration';    value = $cosmosVnet }
        )))
    }

    # ════════════════════════════ Cache — Redis ═════════════════════════════
    $cache = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.cache/redis'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(properties.sku.name), skuFamily = tostring(properties.sku.family), skuCapacity = toint(properties.sku.capacity),
          version = tostring(properties.redisVersion),
          shardCount = toint(properties.shardCount),
          hostName = tostring(properties.hostName),
          nonSslPort = tobool(properties.enableNonSslPort),
          subnetId = tostring(properties.subnetId),
          tags
'@)) {
        $sku = if ($r.skuName) { ("$($r.skuName) $($r.skuFamily)$($r.skuCapacity)").Trim() } else { '' }
        $cache.Add((New-Service 'Azure Cache for Redis' $r @(
            [pscustomobject]@{ label = 'Status';        value = $r.status }
            [pscustomobject]@{ label = 'SKU';           value = $sku }
            [pscustomobject]@{ label = 'Redis version'; value = $r.version }
            [pscustomobject]@{ label = 'Shards';        value = $r.shardCount }
            [pscustomobject]@{ label = 'Host';          value = $r.hostName }
            [pscustomobject]@{ label = 'Non-SSL port';  value = (YesNo $r.nonSslPort) }
            [pscustomobject]@{ label = 'VNet integration'; value = (Get-AerSubnetLabel $r.subnetId) }
        )))
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.cache/redisenterprise'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name), skuCapacity = toint(sku.capacity),
          minTls = tostring(properties.minimumTlsVersion),
          hostName = tostring(properties.hostName),
          tags
'@)) {
        $cache.Add((New-Service 'Azure Managed Redis (Enterprise)' $r @(
            [pscustomobject]@{ label = 'Status';   value = $r.status }
            [pscustomobject]@{ label = 'SKU';      value = $r.skuName }
            [pscustomobject]@{ label = 'Capacity'; value = $r.skuCapacity }
            [pscustomobject]@{ label = 'Min TLS';  value = $r.minTls }
            [pscustomobject]@{ label = 'Host';     value = $r.hostName }
        )))
    }

    # ════════════════════════════ Analytics ═════════════════════════════════
    $analytics = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.synapse/workspaces'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          sqlAdmin = tostring(properties.sqlAdministratorLogin),
          managedRg = tostring(properties.managedResourceGroupName),
          tags
'@)) {
        $analytics.Add((New-Service 'Azure Synapse Analytics' $r @(
            [pscustomobject]@{ label = 'Status';       value = $r.status }
            [pscustomobject]@{ label = 'SQL admin';    value = $r.sqlAdmin }
            [pscustomobject]@{ label = 'Managed RG';   value = $r.managedRg }
        )))
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.kusto/clusters'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier), skuCapacity = toint(sku.capacity),
          uri = tostring(properties.uri),
          tags
'@)) {
        $sku = if ($r.skuCapacity) { "$($r.skuName) ×$($r.skuCapacity)" } else { $r.skuName }
        $analytics.Add((New-Service 'Azure Data Explorer' $r @(
            [pscustomobject]@{ label = 'Status';  value = $r.status }
            [pscustomobject]@{ label = 'SKU';     value = $sku }
            [pscustomobject]@{ label = 'Tier';    value = $r.skuTier }
            [pscustomobject]@{ label = 'URI';     value = $r.uri }
        )))
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.databricks/workspaces'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name),
          workspaceUrl = tostring(properties.workspaceUrl),
          managedRg = tostring(properties.managedResourceGroupId),
          tags
'@)) {
        $analytics.Add((New-Service 'Azure Databricks' $r @(
            [pscustomobject]@{ label = 'Status';        value = $r.status }
            [pscustomobject]@{ label = 'SKU';           value = $r.skuName }
            [pscustomobject]@{ label = 'Workspace URL'; value = $r.workspaceUrl }
            [pscustomobject]@{ label = 'Managed RG';    value = if ($r.managedRg) { ($r.managedRg -split '/')[-1] } else { '' } }
        )))
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.analysisservices/servers'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier),
          tags
'@)) {
        $analytics.Add((New-Service 'Azure Analysis Services' $r @(
            [pscustomobject]@{ label = 'Status'; value = $r.status }
            [pscustomobject]@{ label = 'SKU';    value = $r.skuName }
            [pscustomobject]@{ label = 'Tier';   value = $r.skuTier }
        )))
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.hdinsight/clusters'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.clusterState),
          clusterKind = tostring(properties.clusterDefinition.kind),
          version = tostring(properties.clusterVersion),
          tags
'@)) {
        $analytics.Add((New-Service 'Azure HDInsight' $r @(
            [pscustomobject]@{ label = 'Status';       value = $r.status }
            [pscustomobject]@{ label = 'Cluster type'; value = $r.clusterKind }
            [pscustomobject]@{ label = 'Version';      value = $r.version }
        )))
    }

    # ════════════════════════ Table Storage (storage accounts) ══════════════
    $table = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.storage/storageaccounts'
| where isnotempty(tostring(properties.primaryEndpoints.table))
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.provisioningState),
          skuName = tostring(sku.name), skuKind = tostring(kind),
          accessTier = tostring(properties.accessTier),
          tableEndpoint = tostring(properties.primaryEndpoints.table),
          httpsOnly = tobool(properties.supportsHttpsTrafficOnly),
          minTls = tostring(properties.minimumTlsVersion),
          vnetRules = properties.networkAcls.virtualNetworkRules,
          tags
'@)) {
        $stgVnet = (@($r.vnetRules | ForEach-Object { Get-AerSubnetLabel $_.id } | Where-Object { $_ }) -join ', ')
        $table.Add((New-Service 'Azure Table Storage' $r @(
            [pscustomobject]@{ label = 'Status';         value = $r.status }
            [pscustomobject]@{ label = 'SKU';            value = $r.skuName }
            [pscustomobject]@{ label = 'Kind';           value = $r.skuKind }
            [pscustomobject]@{ label = 'Access tier';    value = $r.accessTier }
            [pscustomobject]@{ label = 'HTTPS only';     value = (YesNo $r.httpsOnly) }
            [pscustomobject]@{ label = 'Min TLS';        value = $r.minTls }
            [pscustomobject]@{ label = 'Table endpoint'; value = $r.tableEndpoint }
            [pscustomobject]@{ label = 'VNet integration'; value = $stgVnet }
        )))
    }

    $nosqlA = @($nosql); $cacheA = @($cache); $analyticsA = @($analytics); $tableA = @($table)
    $cnt = { param($list, $type) @($list | Where-Object { $_.Type -eq $type }).Count }

    return [pscustomobject]@{
        NoSQL = [pscustomobject]@{
            Total = $nosqlA.Count
            Counts = [pscustomobject]@{ CosmosDb = $nosqlA.Count }
            Services = $nosqlA
        }
        Cache = [pscustomobject]@{
            Total = $cacheA.Count
            Counts = [pscustomobject]@{
                Redis           = (& $cnt $cacheA 'Azure Cache for Redis')
                RedisEnterprise = (& $cnt $cacheA 'Azure Managed Redis (Enterprise)')
            }
            Services = $cacheA
        }
        Analytics = [pscustomobject]@{
            Total = $analyticsA.Count
            Counts = [pscustomobject]@{
                Synapse          = (& $cnt $analyticsA 'Azure Synapse Analytics')
                DataExplorer     = (& $cnt $analyticsA 'Azure Data Explorer')
                Databricks       = (& $cnt $analyticsA 'Azure Databricks')
                AnalysisServices = (& $cnt $analyticsA 'Azure Analysis Services')
                HDInsight        = (& $cnt $analyticsA 'Azure HDInsight')
            }
            Services = $analyticsA
        }
        TableStorage = [pscustomobject]@{
            Total = $tableA.Count
            Services = $tableA
        }
    }
}
