function Get-AerSecurityPosture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $SubscriptionIds,
        [Parameter(Mandatory)]            $SubscriptionMap
    )

    $typeMap = @{
        'microsoft.keyvault/vaults'                  = @{ Label = 'Key Vault';            Category = 'Secrets & Keys' }
        'microsoft.keyvault/managedhsms'             = @{ Label = 'Managed HSM';          Category = 'Secrets & Keys' }
        'microsoft.compute/diskencryptionsets'       = @{ Label = 'Disk Encryption Set';  Category = 'Secrets & Keys' }
        'microsoft.managedidentity/userassignedidentities' = @{ Label = 'Managed Identity'; Category = 'Identity' }
        'microsoft.network/networksecuritygroups'    = @{ Label = 'Network Security Group'; Category = 'Network Security' }
        'microsoft.network/azurefirewalls'           = @{ Label = 'Azure Firewall';       Category = 'Network Security' }
        'microsoft.network/firewallpolicies'         = @{ Label = 'Firewall Policy';      Category = 'Network Security' }
        'microsoft.network/ddosprotectionplans'      = @{ Label = 'DDoS Protection Plan'; Category = 'Network Security' }
        'microsoft.network/applicationgatewaywebapplicationfirewallpolicies' = @{ Label = 'WAF Policy (App Gateway)'; Category = 'Network Security' }
        'microsoft.network/frontdoorwebapplicationfirewallpolicies'          = @{ Label = 'WAF Policy (Front Door)';  Category = 'Network Security' }
        'microsoft.network/bastionhosts'             = @{ Label = 'Bastion';              Category = 'Network Security' }
        'microsoft.network/privateendpoints'         = @{ Label = 'Private Endpoint';     Category = 'Network Security' }
    }
    $typeList = "'" + (($typeMap.Keys) -join "','") + "'"
    $rows = @()
    try { $rows = Invoke-AerArgQuery -SubscriptionIds $SubscriptionIds -Query "resources | where type in~ ($typeList) | project type = tolower(type), location" }
    catch { Write-Warning "[SecurityPosture] $($_.Exception.Message)" }

    Get-AerTypeAggregate -Rows $rows -TypeMap $typeMap -CategoryOrder @('Secrets & Keys', 'Identity', 'Network Security')
}
