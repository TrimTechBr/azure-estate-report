#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . "$PSScriptRoot/../Core/ResourceGraph.ps1"
}

Describe 'Invoke-AerArgQuery' {
    It 'returns rows mapped to named properties from a single-page response' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{"data":{"columns":[{"name":"id"},{"name":"type"}],"rows":[["res-1","vm"],["res-2","disk"]]}}'
            }
        }
        $result = Invoke-AerArgQuery -Query 'resources | limit 2' -SubscriptionIds @('sub-aaa')
        $result.Count | Should -Be 2
        $result[0].id   | Should -Be 'res-1'
        $result[0].type | Should -Be 'vm'
        $result[1].id   | Should -Be 'res-2'
    }

    It 'follows skipToken to retrieve a second page' {
        $script:callCount = 0
        Mock Invoke-AzRestMethod {
            $script:callCount++
            if ($script:callCount -eq 1) {
                [pscustomobject]@{
                    StatusCode = 200
                    Content    = '{"data":{"columns":[{"name":"id"}],"rows":[["res-1"]]},"$skipToken":"tok-abc"}'
                }
            } else {
                [pscustomobject]@{
                    StatusCode = 200
                    Content    = '{"data":{"columns":[{"name":"id"}],"rows":[["res-2"]]}}'
                }
            }
        }
        $result = Invoke-AerArgQuery -Query 'resources' -SubscriptionIds @('sub-aaa')
        $result.Count | Should -Be 2
        $result[1].id  | Should -Be 'res-2'
    }

    It 'throws when the API returns a non-200 status code' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{ StatusCode = 403; Content = '{"error":{"code":"Forbidden"}}' }
        }
        { Invoke-AerArgQuery -Query 'resources' -SubscriptionIds @('sub-aaa') } | Should -Throw
    }

    It 'returns empty array when data.rows is null' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{"data":{"columns":[{"name":"id"}],"rows":null}}'
            }
        }
        $result = Invoke-AerArgQuery -Query 'resources | limit 0' -SubscriptionIds @('sub-aaa')
        $result.Count | Should -Be 0
    }
}
