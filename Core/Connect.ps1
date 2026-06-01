function Resolve-AerContext {
    [CmdletBinding()]
    param(
        [string[]] $SubscriptionId,
        [string[]] $ExcludeSubscriptionName = @()
    )

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $context -or $null -eq $context.Account) {
        Write-Host "No Azure context found. Launching interactive login..." -ForegroundColor Yellow
        Connect-AzAccount -ErrorAction Stop | Out-Null
        $context = Get-AzContext -ErrorAction Stop
    }

    $subs = @(Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq 'Enabled' })

    if ($SubscriptionId -and $SubscriptionId.Count -gt 0) {
        $wanted = @($SubscriptionId | ForEach-Object { $_.Trim().ToLowerInvariant() })
        $subs   = @($subs | Where-Object { $wanted -contains $_.Id.ToLowerInvariant() })
    }

    foreach ($pattern in $ExcludeSubscriptionName) {
        if (-not [string]::IsNullOrWhiteSpace($pattern)) {
            $subs = @($subs | Where-Object { $_.Name -notlike "*$pattern*" })
        }
    }

    if ($subs.Count -eq 0) { throw "No enabled subscriptions match the provided filters." }

    $map = @{}
    foreach ($s in $subs) { $map[$s.Id.ToLowerInvariant()] = $s.Name }

    return [pscustomobject]@{
        TenantId        = $context.Tenant.Id
        TenantDomain    = $context.Tenant.Domain ?? $context.Tenant.Id
        Account         = $context.Account.Id
        Subscriptions   = @($subs)
        SubscriptionIds = @($subs | ForEach-Object { $_.Id })
        SubscriptionMap = $map
    }
}
