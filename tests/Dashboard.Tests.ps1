#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . "$PSScriptRoot/../Core/Helpers.ps1"
    . "$PSScriptRoot/../Renderer/Export.ps1"
    . "$PSScriptRoot/../Renderer/Assets/Style.ps1"
    . "$PSScriptRoot/../Renderer/Assets/Script.ps1"
    . "$PSScriptRoot/../Renderer/Dashboard.ps1"

    $script:mockData = [pscustomobject]@{
        metadata  = [pscustomobject]@{
            GeneratedAt   = '2026-05-28 15:00:00 UTC'
            TenantDomain  = 'contoso.com'
            Account       = 'aer@contoso.com'
            DurationMs    = 5000
            ModuleVersion = '0.1.0-test'
        }
        inventory = [pscustomobject]@{
            ManagementGroups    = 2
            Subscriptions       = 5
            TotalResourceGroups = 20
            TotalResources      = 100
            BySubscription      = @([pscustomobject]@{ SubscriptionId = 'sub-1'; SubscriptionName = 'Platform'; Count = 80 })
            ByType              = @([pscustomobject]@{ Type = 'virtualMachines'; Count = 30 })
            ByRegion            = @([pscustomobject]@{ Region = 'eastus'; Count = 60 })
            SubscriptionMap     = @{ 'sub-1' = 'Platform' }
            ResourceList        = @([pscustomobject]@{
                id = '/subscriptions/sub-1/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1'
                subscriptionId = 'sub-1'
                resourceGroup = 'rg'
                name = 'vm1'
                type = 'microsoft.compute/virtualmachines'
                location = 'eastus'
                provisioningState = 'Succeeded'
                tags = @{ owner = 'platform' }
            })
        }
        security  = [pscustomobject]@{ TotalGaps = 3; Items = @([pscustomobject]@{ Severity = 'High'; Title = 'Open management ports'; ResourceType = 'microsoft.compute/virtualmachines'; Count = 2; Resources = @() }) }
        cost      = [pscustomobject]@{ TotalWastedResources = 2; Items = @([pscustomobject]@{ Severity = 'Waste'; Title = 'Idle disks'; ResourceType = 'microsoft.compute/disks'; Count = 2; Resources = @() }) }
        advisor   = [pscustomobject]@{ TotalRecommendations = 4; HighImpactCount = 1; ByCategory = @(); Recommendations = @([pscustomobject]@{
            Category       = 'Cost'
            Impact         = 'High'
            Problem        = 'Resize VM'
            Resource       = 'vm1'
            ResourceType   = 'VM'
            SubscriptionId = 'sub-1'
            ResourceId     = '/subscriptions/sub-1/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1'
        }) }
        virtualMachines = [pscustomobject]@{ TotalVMs = 1; VirtualMachines = @() }
        databases = [pscustomobject]@{ TotalServices = 0 }
        policy = [pscustomobject]@{ Assignments = [pscustomobject]@{ Total = 0 }; Items = @() }
        defender = [pscustomobject]@{ Summary = [pscustomobject]@{ Unhealthy = 0 }; Recommendations = @() }
        collectionErrors = @()
    }

    $script:outputPath = Join-Path ([IO.Path]::GetTempPath()) ("aer-dashboard-test-" + [guid]::NewGuid().ToString('N'))
    $script:indexPath = New-AerReportSite -ReportData $script:mockData -OutputPath $script:outputPath
    $script:indexHtml = Get-Content -Path $script:indexPath -Raw
}

AfterAll {
    if ($script:outputPath -and (Test-Path -LiteralPath $script:outputPath)) {
        Remove-Item -LiteralPath $script:outputPath -Recurse -Force
    }
}

Describe 'New-AerReportSite' {
    It 'writes the overview HTML page' {
        $script:indexPath | Should -Exist
        $script:indexHtml | Should -Match '<!DOCTYPE html>'
        $script:indexHtml | Should -Match 'id="kpi-grid"'
    }

    It 'embeds data and export metadata' {
        $dataJs = Get-Content -Path (Join-Path $script:outputPath 'assets/data.js') -Raw
        $dataJs | Should -Match 'window\.AerData\s*='
        $dataJs | Should -Match '"TotalResources"'
        $dataJs | Should -Match '"ExportFiles"'
    }

    It 'renders XLSX and PDF export buttons on the overview page' {
        $script:indexHtml | Should -Match 'href="exports/aer-report.xlsx"'
        $script:indexHtml | Should -Match 'href="exports/aer-report.pdf"'
    }

    It 'generates valid export artifacts' {
        $xlsx = Join-Path $script:outputPath 'exports/aer-report.xlsx'
        $pdf = Join-Path $script:outputPath 'exports/aer-report.pdf'

        $xlsx | Should -Exist
        $pdf | Should -Exist

        $pdfHeader = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($pdf), 0, 5)
        $pdfHeader | Should -Be '%PDF-'
        $pdfText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($pdf))
        $pdfText | Should -Match 'microsoft.compute/virtualmachines'
        $pdfText | Should -Match 'Resize VM'
        $pdfText | Should -Match 'vm1'
        $pdfText | Should -Match 'Platform'

        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($xlsx)
        try {
            @($zip.Entries | Where-Object FullName -eq 'xl/workbook.xml').Count | Should -Be 1
            @($zip.Entries | Where-Object FullName -like 'xl/worksheets/sheet*.xml').Count | Should -BeGreaterThan 1
            $worksheetText = foreach ($entry in @($zip.Entries | Where-Object FullName -like 'xl/worksheets/sheet*.xml')) {
                $reader = [IO.StreamReader]::new($entry.Open())
                try { $reader.ReadToEnd() } finally { $reader.Dispose() }
            }
            ($worksheetText -join "`n") | Should -Match 'microsoft.compute/virtualmachines'
            ($worksheetText -join "`n") | Should -Match 'Resize VM'
            ($worksheetText -join "`n") | Should -Match 'vm1'
            ($worksheetText -join "`n") | Should -Match 'Platform'
        } finally {
            $zip.Dispose()
        }
    }
}
