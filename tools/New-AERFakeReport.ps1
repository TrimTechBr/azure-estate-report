[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\output-test\aer-fake-report')
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $repoRoot 'Core\SampleData.ps1')
. (Join-Path $repoRoot 'Renderer\Export.ps1')
. (Join-Path $repoRoot 'Renderer\Assets\Style.ps1')
. (Join-Path $repoRoot 'Renderer\Assets\Script.ps1')
. (Join-Path $repoRoot 'Renderer\Dashboard.ps1')

$reportData = New-AerSampleReportData -ModuleVersion '0.1.0'
$index = New-AerReportSite -ReportData $reportData -OutputPath $OutputPath

[pscustomobject]@{
    OutputPath = (Resolve-Path $OutputPath).Path
    IndexHtml  = (Resolve-Path $index).Path
    Xlsx       = (Resolve-Path (Join-Path $OutputPath 'exports\aer-report.xlsx')).Path
    Pdf        = (Resolve-Path (Join-Path $OutputPath 'exports\aer-report.pdf')).Path
    Pages      = 33
    Resources  = $reportData.inventory.TotalResources
}
