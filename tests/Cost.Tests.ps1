#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . "$PSScriptRoot/../Core/ResourceGraph.ps1"
    . "$PSScriptRoot/../Collectors/Cost.ps1"
}

Describe 'Get-AerCostWaste' {
    It 'returns total item count across all checks' {
        Mock Invoke-AerArgQuery { return @([pscustomobject]@{ Count = 3 }) }
        $result = Get-AerCostWaste -SubscriptionIds @('sub-1')
        $result.Items.Count | Should -Be 5   # 5 waste checks
    }

    It 'sums TotalWastedResources correctly' {
        Mock Invoke-AerArgQuery { return @([pscustomobject]@{ Count = 2 }) }
        $result = Get-AerCostWaste -SubscriptionIds @('sub-1')
        $result.TotalWastedResources | Should -Be 10   # 5 checks × 2
    }

    It 'returns 0 total when all queries return 0' {
        Mock Invoke-AerArgQuery { return @([pscustomobject]@{ Count = 0 }) }
        $result = Get-AerCostWaste -SubscriptionIds @('sub-1')
        $result.TotalWastedResources | Should -Be 0
    }
}
