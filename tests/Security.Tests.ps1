#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . "$PSScriptRoot/../Core/ResourceGraph.ps1"
    . "$PSScriptRoot/../Collectors/Security.ps1"
}

Describe 'Get-AerSecurityGaps' {
    It 'returns correct TotalGaps count' {
        Mock Invoke-AerArgQuery { param($Query)
            return @([pscustomobject]@{ Count = 2 })
        }
        $result = Get-AerSecurityGaps -SubscriptionIds @('sub-1')
        $result.TotalGaps | Should -Be 10   # 5 checks × 2
    }

    It 'returns items sorted Critical first' {
        Mock Invoke-AerArgQuery { return @([pscustomobject]@{ Count = 1 }) }
        $result = Get-AerSecurityGaps -SubscriptionIds @('sub-1')
        $result.Items[0].Severity | Should -Be 'Critical'
    }

    It 'returns 0 gaps when all queries return 0' {
        Mock Invoke-AerArgQuery { return @([pscustomobject]@{ Count = 0 }) }
        $result = Get-AerSecurityGaps -SubscriptionIds @('sub-1')
        $result.TotalGaps | Should -Be 0
    }

    It 'returns exactly 5 gap categories' {
        Mock Invoke-AerArgQuery { return @([pscustomobject]@{ Count = 1 }) }
        $result = Get-AerSecurityGaps -SubscriptionIds @('sub-1')
        $result.Items.Count | Should -Be 5
    }
}
