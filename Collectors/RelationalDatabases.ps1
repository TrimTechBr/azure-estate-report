function Get-AerRelationalDatabases {
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
    function Format-Tier($name, $tier) {
        if ($tier -and $name) { "$tier · $name" }
        elseif ($name)        { $name }
        elseif ($tier)        { $tier }
        else                  { '' }
    }

    $arg = { param($q) try { Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $q } catch { Write-Warning "[RelationalDatabases] $($_.Exception.Message)"; @() } }

    $services = [System.Collections.Generic.List[object]]::new()

    # ── Azure SQL Database (exclude the system 'master' DB) ──────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.sql/servers/databases'
| where name !~ 'master'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.status),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier),
          maxSizeBytes = tolong(properties.maxSizeBytes),
          elasticPoolId = tostring(properties.elasticPoolId),
          tags
'@)) {
        $services.Add([pscustomobject]@{
            Type = 'Azure SQL Database'; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            PricingTier = (Format-Tier $r.skuName $r.skuTier)
            MaxStorageGB = if ($r.maxSizeBytes) { [int][math]::Round([double]$r.maxSizeBytes / 1073741824, 0) } else { 0 }
            ElasticPool = if ($r.elasticPoolId) { ($r.elasticPoolId -split '/')[-1] } else { '' }
            Server = if ($r.id -match '/servers/([^/]+)/') { $matches[1] } else { '' }
            AdminLogin = ''; Version = ''; StorageGB = 0; VCores = 0
            DatabaseCount = $null; Databases = @(); HaMode = ''; BackupRetentionDays = $null; NodeCount = $null
        })
    }

    # ── Azure SQL Managed Instance (+ child database counts) ─────────────────
    $miDbs = @{}
    foreach ($d in (& $arg @'
resources
| where type =~ 'microsoft.sql/managedinstances/databases'
| project name, miId = tolower(strcat_array(array_slice(split(id, '/'), 0, -3), '/'))
'@)) {
        if (-not $d.miId) { continue }
        if (-not $miDbs.ContainsKey($d.miId)) { $miDbs[$d.miId] = [System.Collections.Generic.List[string]]::new() }
        $miDbs[$d.miId].Add($d.name)
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.sql/managedinstances'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier),
          vCores = toint(properties.vCores),
          storageSizeInGB = toint(properties.storageSizeInGB),
          adminLogin = tostring(properties.administratorLogin),
          subnetId = tostring(properties.subnetId),
          tags
'@)) {
        $idLower = if ($r.id) { $r.id.ToLowerInvariant() } else { '' }
        $dbs = if ($idLower -and $miDbs.ContainsKey($idLower)) { @($miDbs[$idLower]) } else { @() }
        $services.Add([pscustomobject]@{
            Type = 'Azure SQL Managed Instance'; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            PricingTier = (Format-Tier $r.skuName $r.skuTier)
            MaxStorageGB = [int]$r.storageSizeInGB; VCores = [int]$r.vCores; AdminLogin = $r.adminLogin
            DatabaseCount = $dbs.Count; Databases = $dbs; VnetIntegration = (Get-AerSubnetLabel $r.subnetId)
            ElasticPool = ''; Server = ''; Version = ''; StorageGB = 0; HaMode = ''; BackupRetentionDays = $null; NodeCount = $null
        })
    }

    # ── Azure Database for PostgreSQL Flexible Server ────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.dbforpostgresql/flexibleservers'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state),
          version = tostring(properties.version),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier),
          storageGB = toint(properties.storage.storageSizeGB),
          adminLogin = tostring(properties.administratorLogin),
          haMode = tostring(properties.highAvailability.mode),
          backupRetentionDays = toint(properties.backup.backupRetentionDays),
          subnetId = tostring(properties.network.delegatedSubnetResourceId),
          tags
'@)) {
        $services.Add([pscustomobject]@{
            Type = 'Azure DB for PostgreSQL Flexible'; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            PricingTier = (Format-Tier $r.skuName $r.skuTier)
            Version = $r.version; StorageGB = [int]$r.storageGB; AdminLogin = $r.adminLogin
            HaMode = $r.haMode; BackupRetentionDays = $r.backupRetentionDays; VnetIntegration = (Get-AerSubnetLabel $r.subnetId)
            MaxStorageGB = 0; VCores = 0; ElasticPool = ''; Server = ''; DatabaseCount = $null; Databases = @(); NodeCount = $null
        })
    }

    # ── Azure Database for MySQL Flexible Server ─────────────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.dbformysql/flexibleservers'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state),
          version = tostring(properties.version),
          skuName = tostring(sku.name), skuTier = tostring(sku.tier),
          storageGB = toint(properties.storage.storageSizeGB),
          adminLogin = tostring(properties.administratorLogin),
          subnetId = tostring(properties.network.delegatedSubnetResourceId),
          tags
'@)) {
        $services.Add([pscustomobject]@{
            Type = 'Azure DB for MySQL Flexible'; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            PricingTier = (Format-Tier $r.skuName $r.skuTier)
            Version = $r.version; StorageGB = [int]$r.storageGB; AdminLogin = $r.adminLogin
            HaMode = ''; BackupRetentionDays = $null; MaxStorageGB = 0; VCores = 0; VnetIntegration = (Get-AerSubnetLabel $r.subnetId)
            ElasticPool = ''; Server = ''; DatabaseCount = $null; Databases = @(); NodeCount = $null
        })
    }

    # ── Azure Cosmos DB for PostgreSQL (server groups v2) ────────────────────
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.dbforpostgresql/servergroupsv2'
| project id, name, subscriptionId, resourceGroup, location,
          status = tostring(properties.state),
          version = tostring(properties.postgresqlVersion),
          nodeCount = toint(array_length(properties.serverNames)),
          tags
'@)) {
        $services.Add([pscustomobject]@{
            Type = 'Cosmos DB for PostgreSQL'; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $r.status; Tags = $r.tags
            Version = $r.version; NodeCount = $r.nodeCount
            PricingTier = ''; MaxStorageGB = 0; StorageGB = 0; VCores = 0; AdminLogin = ''
            ElasticPool = ''; Server = ''; DatabaseCount = $null; Databases = @(); HaMode = ''; BackupRetentionDays = $null
        })
    }

    # ── SQL Server running on Azure VMs (detected by the VM image) ───────────
    $sqlVmMeta = @{}
    foreach ($s in (& $arg @'
resources
| where type =~ 'microsoft.sqlvirtualmachine/sqlvirtualmachines'
| project vmId = tolower(tostring(properties.virtualMachineResourceId)),
          sqlImageOffer = tostring(properties.sqlImageOffer),
          sqlImageSku   = tostring(properties.sqlImageSku),
          licenseType   = tostring(properties.sqlServerLicenseType),
          mgmt          = tostring(properties.sqlManagementType)
'@)) {
        if ($s.vmId) { $sqlVmMeta[$s.vmId] = $s }
    }
    foreach ($r in (& $arg @'
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend imgPublisher = tostring(properties.storageProfile.imageReference.publisher),
         imgOffer = tostring(properties.storageProfile.imageReference.offer),
         imgSku = tostring(properties.storageProfile.imageReference.sku)
| where imgPublisher =~ 'microsoftsqlserver' or imgOffer contains 'sql'
| project id, name, subscriptionId, resourceGroup, location,
          powerState = tostring(properties.extended.instanceView.powerState.code),
          osType = tostring(properties.storageProfile.osDisk.osType),
          vmSize = tostring(properties.hardwareProfile.vmSize),
          imgPublisher, imgOffer, imgSku,
          tags
'@)) {
        $meta  = if ($r.id) { $sqlVmMeta[$r.id.ToLowerInvariant()] } else { $null }
        $img   = (@($r.imgPublisher, $r.imgOffer, $r.imgSku) | Where-Object { $_ }) -join ':'
        $power = if ($r.powerState) { ($r.powerState -split '/')[-1] } else { '' }
        $edition = if ($meta -and $meta.sqlImageSku) { $meta.sqlImageSku } elseif ($meta -and $meta.sqlImageOffer) { $meta.sqlImageOffer } else { '' }
        $services.Add([pscustomobject]@{
            Type = 'SQL Server on Azure VM'; Name = $r.name; Id = $r.id
            SubscriptionId = $r.subscriptionId; SubscriptionName = (Resolve-SubName $r.subscriptionId)
            ResourceGroup = $r.resourceGroup; Location = $r.location; Status = $power; Tags = $r.tags
            Image = $img; Os = $r.osType; VmSize = $r.vmSize
            SqlEdition = $edition
            LicenseType = if ($meta) { $meta.licenseType } else { '' }
            ManagementMode = if ($meta) { $meta.mgmt } else { '' }
            PricingTier = ''; MaxStorageGB = 0; StorageGB = 0; VCores = 0; AdminLogin = ''; Version = ''
            ElasticPool = ''; Server = ''; DatabaseCount = $null; Databases = @(); HaMode = ''; BackupRetentionDays = $null; NodeCount = $null
        })
    }

    $all = @($services)
    $countByType = { param($t) @($all | Where-Object { $_.Type -eq $t }).Count }

    return [pscustomobject]@{
        TotalRelational = $all.Count
        Counts = [pscustomobject]@{
            SqlDatabase        = (& $countByType 'Azure SQL Database')
            SqlManagedInstance = (& $countByType 'Azure SQL Managed Instance')
            SqlOnVm            = (& $countByType 'SQL Server on Azure VM')
            PostgresFlexible   = (& $countByType 'Azure DB for PostgreSQL Flexible')
            MysqlFlexible      = (& $countByType 'Azure DB for MySQL Flexible')
            CosmosPostgres     = (& $countByType 'Cosmos DB for PostgreSQL')
        }
        Services = $all
    }
}
