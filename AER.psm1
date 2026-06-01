# Aer.psm1
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Core\*.ps1" -ErrorAction SilentlyContinue)
$Private += @(Get-ChildItem -Path "$PSScriptRoot\Collectors\*.ps1" -ErrorAction SilentlyContinue)
$Private += @(Get-ChildItem -Path "$PSScriptRoot\Renderer\*.ps1" -ErrorAction SilentlyContinue)
$Private += @(Get-ChildItem -Path "$PSScriptRoot\Renderer\Assets\*.ps1" -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in ($Private + $Public)) {
    try   { . $file.FullName }
    catch { Write-Error "Failed to dot-source $($file.FullName): $_" }
}

Export-ModuleMember -Function ($Public | Select-Object -ExpandProperty BaseName)
