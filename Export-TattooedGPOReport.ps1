<#
.SYNOPSIS
    Enumerates all policy registry values under HKLM:\SOFTWARE\Policies to inventory GPO footprint and potential tattooing.
.DESCRIPTION
    Recursively scans HKLM:\SOFTWARE\Policies\Microsoft and outputs every configured policy value,
    making it easy to inventory legacy Group Policies before migrating to Intune Settings Catalog.
.PARAMETER ExportCsv
    Optional file path to export the full registry inventory as CSV.
.EXAMPLE
    .\Export-TattooedGPOReport.ps1 -ExportCsv "C:\Temp\GPO-Policy-Inventory.csv"
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportCsv
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       AdminSignal GPO Registry Footprint Scanner         " -ForegroundColor Cyan
Write-Host "       https://adminsignal.com                           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$rootPath = "HKLM:\SOFTWARE\Policies\Microsoft"
$inventory = [System.Collections.Generic.List[PSCustomObject]]::new()

if (Test-Path $rootPath) {
    $keys = Get-ChildItem -Path $rootPath -Recurse -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        $propNames = $k.GetValueNames()
        foreach ($name in $propNames) {
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $val = $k.GetValue($name)
                $kind = $k.GetValueKind($name)
                $relPath = $k.Name -replace "^HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\", ""
                $topArea = ($relPath -split "\\")[0]

                $inventory.Add([PSCustomObject]@{
                    Area         = $topArea
                    RelativePath = $relPath
                    ValueName    = $name
                    ValueData    = if ($val -is [array]) { $val -join "," } else { "$val" }
                    ValueType    = $kind.ToString()
                })
            }
        }
    }
}

Write-Host "`n[+] Discovered $($inventory.Count) policy registry value(s) under $rootPath" -ForegroundColor Yellow
$inventory | Group-Object -Property Area | Select-Object Name, Count | Sort-Object Count -Descending | Format-Table -AutoSize

if ($ExportCsv) {
    $inventory | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "[+] Full GPO registry inventory exported to: $ExportCsv" -ForegroundColor Green
} else {
    $inventory | Select-Object -First 25 | Format-Table Area, ValueName, ValueData, ValueType -AutoSize
}
