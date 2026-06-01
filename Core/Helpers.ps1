function ConvertTo-AerFlatString {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [array] -or $Value -is [System.Collections.IEnumerable]) {
        return ($Value | ForEach-Object { ConvertTo-AerFlatString $_ }) -join '; '
    }
    return $Value.ToString()
}

function Get-AerSafeCount {
    param($Collection)
    if ($null -eq $Collection) { return 0 }
    if ($Collection -is [array]) { return $Collection.Count }
    if ($Collection -is [System.Collections.ICollection]) { return $Collection.Count }
    return 1
}
