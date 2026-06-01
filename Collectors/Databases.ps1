function Get-AerDatabases {
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

    # ── Resource type → friendly label + category. Adjust here to retune. ────
    $typeMap = [ordered]@{
        'microsoft.sql/servers/databases'                = @{ Label = 'Azure SQL Database';              Category = 'Relational' }
        'microsoft.sql/managedinstances'                 = @{ Label = 'Azure SQL Managed Instance';       Category = 'Relational' }
        'microsoft.sqlvirtualmachine/sqlvirtualmachines' = @{ Label = 'SQL Server on Azure VM (IaaS)';    Category = 'Relational' }
        'microsoft.dbformysql/flexibleservers'           = @{ Label = 'Azure DB for MySQL Flexible';      Category = 'Relational' }
        'microsoft.dbformysql/servers'                   = @{ Label = 'Azure DB for MySQL (Single)';      Category = 'Relational' }
        'microsoft.dbforpostgresql/flexibleservers'      = @{ Label = 'Azure DB for PostgreSQL Flexible'; Category = 'Relational' }
        'microsoft.dbforpostgresql/servers'              = @{ Label = 'Azure DB for PostgreSQL (Single)'; Category = 'Relational' }
        'microsoft.dbforpostgresql/servergroupsv2'       = @{ Label = 'Cosmos DB for PostgreSQL';         Category = 'Relational' }
        'microsoft.dbformariadb/servers'                 = @{ Label = 'Azure DB for MariaDB';             Category = 'Relational' }
        'oracle.database/autonomousdatabases'            = @{ Label = 'Oracle Autonomous Database';       Category = 'Relational' }
        'oracle.database/cloudvmclusters'                = @{ Label = 'Oracle Exadata (VM Cluster)';      Category = 'Relational' }
        'microsoft.documentdb/databaseaccounts'          = @{ Label = 'Azure Cosmos DB';                  Category = 'NoSQL' }
        'microsoft.cache/redis'                          = @{ Label = 'Azure Cache for Redis';            Category = 'Cache' }
        'microsoft.cache/redisenterprise'               = @{ Label = 'Azure Managed Redis (Enterprise)'; Category = 'Cache' }
        'microsoft.synapse/workspaces'                   = @{ Label = 'Azure Synapse Analytics';          Category = 'Analytics' }
        'microsoft.kusto/clusters'                       = @{ Label = 'Azure Data Explorer';              Category = 'Analytics' }
        'microsoft.databricks/workspaces'                = @{ Label = 'Azure Databricks';                 Category = 'Analytics' }
        'microsoft.analysisservices/servers'             = @{ Label = 'Azure Analysis Services';          Category = 'Analytics' }
        'microsoft.hdinsight/clusters'                   = @{ Label = 'Azure HDInsight';                  Category = 'Analytics' }
    }

    $typeList = "'" + (($typeMap.Keys) -join "','") + "'"
    $query = @"
resources
| where type in~ ($typeList)
| where not(type =~ 'microsoft.sql/servers/databases' and name =~ 'master')
| project id, name, type = tolower(type), subscriptionId, resourceGroup, location,
          skuName      = tostring(sku.name),
          propsSkuName = tostring(properties.sku.name),
          acctKind     = tostring(kind),
          capabilities = properties.capabilities
"@

    $rows = @()
    try { $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query $query }
    catch { Write-Warning "[Databases.resources] $($_.Exception.Message)" }

    $byType   = @{}   # label -> count
    $labelCat = @{}   # label -> category
    $byCat    = @{}   # category -> count
    $byLoc    = @{}   # region -> count
    $cosmos   = @{}   # api -> count
    $redis    = @{}   # tier -> count

    foreach ($r in $rows) {
        $meta = $typeMap[$r.type]
        if (-not $meta) { continue }
        $label = $meta.Label
        $cat   = $meta.Category

        $byType[$label]   = ([int]($byType[$label]   ?? 0)) + 1
        $labelCat[$label] = $cat
        $byCat[$cat]      = ([int]($byCat[$cat]       ?? 0)) + 1
        $loc = if ($r.location) { $r.location } else { '—' }
        $byLoc[$loc]      = ([int]($byLoc[$loc]       ?? 0)) + 1

        if ($r.type -eq 'microsoft.documentdb/databaseaccounts') {
            $api = 'NoSQL (Core)'
            if ($r.acctKind -match 'MongoDB') {
                $api = 'MongoDB'
            } elseif ($r.capabilities) {
                $caps = @($r.capabilities | ForEach-Object { $_.name })
                if     ($caps -contains 'EnableCassandra') { $api = 'Cassandra' }
                elseif ($caps -contains 'EnableGremlin')   { $api = 'Gremlin' }
                elseif ($caps -contains 'EnableTable')     { $api = 'Table' }
                elseif ($caps -contains 'EnableMongo')     { $api = 'MongoDB' }
            }
            $cosmos[$api] = ([int]($cosmos[$api] ?? 0)) + 1
        } elseif ($r.type -eq 'microsoft.cache/redis') {
            $tier = if ($r.propsSkuName) { $r.propsSkuName } else { 'Unknown' }
            $redis[$tier] = ([int]($redis[$tier] ?? 0)) + 1
        } elseif ($r.type -eq 'microsoft.cache/redisenterprise') {
            $redis['Enterprise'] = ([int]($redis['Enterprise'] ?? 0)) + 1
        }
    }

    # Table-capable storage accounts — a proxy for Azure Table Storage usage
    # (kept as a separate metric so it doesn't skew the category charts).
    $tableStorage = 0
    try {
        $ts = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query @'
resources
| where type =~ 'microsoft.storage/storageaccounts'
| where isnotempty(tostring(properties.primaryEndpoints.table))
| summarize Count = count()
'@
        $tableStorage = [int](($ts | Select-Object -First 1).Count ?? 0)
    } catch { Write-Warning "[Databases.tableStorage] $($_.Exception.Message)" }

    $catOrder = @('Relational', 'NoSQL', 'Cache', 'Analytics')
    $byCategory = foreach ($c in $catOrder) {
        [pscustomobject]@{ Category = $c; Count = [int]($byCat[$c] ?? 0) }
    }

    $byTypeList = $byType.GetEnumerator() |
        Sort-Object Value -Descending |
        ForEach-Object {
            [pscustomobject]@{ Label = $_.Key; Category = $labelCat[$_.Key]; Count = [int]$_.Value }
        }

    $byLocation = $byLoc.GetEnumerator() |
        Sort-Object Value -Descending | Select-Object -First 10 |
        ForEach-Object { [pscustomobject]@{ Region = $_.Key; Count = [int]$_.Value } }

    $cosmosFamilies = $cosmos.GetEnumerator() |
        Sort-Object Value -Descending |
        ForEach-Object { [pscustomobject]@{ Api = $_.Key; Count = [int]$_.Value } }

    $redisFamilies = $redis.GetEnumerator() |
        Sort-Object Value -Descending |
        ForEach-Object { [pscustomobject]@{ Tier = $_.Key; Count = [int]$_.Value } }

    return [pscustomobject]@{
        TotalServices   = ($rows | Measure-Object).Count
        Relational      = [int]($byCat['Relational'] ?? 0)
        NoSQL           = [int]($byCat['NoSQL'] ?? 0)
        Cache           = [int]($byCat['Cache'] ?? 0)
        Analytics       = [int]($byCat['Analytics'] ?? 0)
        DistinctTypes   = @($byTypeList).Count
        TableStorage    = $tableStorage
        ByCategory      = @($byCategory)
        ByType          = @($byTypeList)
        ByLocation      = @($byLocation)
        CosmosFamilies  = @($cosmosFamilies)
        RedisFamilies   = @($redisFamilies)
    }
}
