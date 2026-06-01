#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . "$PSScriptRoot/../Core/ResourceGraph.ps1"
    . "$PSScriptRoot/../Core/Helpers.ps1"
    . "$PSScriptRoot/../Collectors/Inventory.ps1"
}

Describe 'Get-AerInventory' {
    BeforeEach {
        Mock Invoke-AerArgQuery {
            param($Query)
            if ($Query -match 'resourcegroups') {
                return @([pscustomobject]@{ subscriptionId = 'sub-1'; ResourceGroups = 15 })
            }
            return @(
                [pscustomobject]@{ subscriptionId = 'sub-1'; type = 'microsoft.compute/virtualmachines'; location = 'brazilsouth'; Count = 10 },
                [pscustomobject]@{ subscriptionId = 'sub-1'; type = 'microsoft.storage/storageaccounts'; location = 'eastus2';    Count = 5  }
            )
        }
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{"value":[{"id":"/providers/Microsoft.Management/managementGroups/mg1"},{"id":"/providers/Microsoft.Management/managementGroups/mg2"}]}'
            }
        }
    }

    It 'returns correct total resource count' {
        $subMap = @{ 'sub-1' = 'My Subscription' }
        $result = Get-AerInventory -SubscriptionIds @('sub-1') -SubscriptionMap $subMap
        $result.TotalResources | Should -Be 15
    }

    It 'returns correct resource group count' {
        $subMap = @{ 'sub-1' = 'My Subscription' }
        $result = Get-AerInventory -SubscriptionIds @('sub-1') -SubscriptionMap $subMap
        $result.TotalResourceGroups | Should -Be 15
    }

    It 'returns management group count from ARM REST' {
        $subMap = @{ 'sub-1' = 'My Subscription' }
        $result = Get-AerInventory -SubscriptionIds @('sub-1') -SubscriptionMap $subMap
        $result.ManagementGroups | Should -Be 2
    }

    It 'builds ByType with simplified type names' {
        $subMap = @{ 'sub-1' = 'My Subscription' }
        $result = Get-AerInventory -SubscriptionIds @('sub-1') -SubscriptionMap $subMap
        $result.ByType[0].Type | Should -Be 'virtualmachines'
        $result.ByType[0].Count | Should -Be 10
    }

    It 'returns 0 management groups when ARM REST returns non-200' {
        Mock Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
        $subMap = @{ 'sub-1' = 'My Subscription' }
        $result = Get-AerInventory -SubscriptionIds @('sub-1') -SubscriptionMap $subMap
        $result.ManagementGroups | Should -Be 0
    }
}
