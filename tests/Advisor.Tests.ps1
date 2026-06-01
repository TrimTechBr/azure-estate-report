#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . "$PSScriptRoot/../Collectors/Advisor.ps1"
}

Describe 'Get-AerAdvisorSummary' {
    It 'aggregates recommendations by category across subscriptions' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{"value":[{"properties":{"category":"Security","impact":"High"}},{"properties":{"category":"Security","impact":"Medium"}},{"properties":{"category":"Cost","impact":"High"}}]}'
            }
        }
        $result = Get-AerAdvisorSummary -SubscriptionIds @('sub-1')
        $secCat = $result.ByCategory | Where-Object Category -eq 'Security'
        $secCat.Count | Should -Be 2
    }

    It 'counts HighImpactCount correctly' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{"value":[{"properties":{"category":"Security","impact":"High"}},{"properties":{"category":"Cost","impact":"High"}},{"properties":{"category":"Reliability","impact":"Medium"}}]}'
            }
        }
        $result = Get-AerAdvisorSummary -SubscriptionIds @('sub-1')
        $result.HighImpactCount | Should -Be 2
    }

    It 'returns 0 recommendations when API returns 403' {
        Mock Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
        $result = Get-AerAdvisorSummary -SubscriptionIds @('sub-1')
        $result.TotalRecommendations | Should -Be 0
    }

    It 'returns all 5 standard categories even when some have 0 recommendations' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{"value":[{"properties":{"category":"Security","impact":"High"}}]}'
            }
        }
        $result = Get-AerAdvisorSummary -SubscriptionIds @('sub-1')
        $result.ByCategory.Count | Should -Be 5
    }

    It 'follows nextLink pagination to collect all recommendations' {
        $script:advisorCallCount = 0
        Mock Invoke-AzRestMethod {
            $script:advisorCallCount++
            if ($script:advisorCallCount -eq 1) {
                [pscustomobject]@{
                    StatusCode = 200
                    Content    = '{"value":[{"properties":{"category":"Security","impact":"High"}}],"nextLink":"https://management.azure.com/subscriptions/sub-1/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&$skiptoken=abc"}'
                }
            } else {
                [pscustomobject]@{
                    StatusCode = 200
                    Content    = '{"value":[{"properties":{"category":"Cost","impact":"Medium"}}]}'
                }
            }
        }
        $result = Get-AerAdvisorSummary -SubscriptionIds @('sub-1')
        $result.TotalRecommendations | Should -Be 2
    }
}
