<#
.SYNOPSIS
    Audits MDMWinsOverGP state, Intune CSP policies, and legacy GPO policies on a Windows client.
.DESCRIPTION
    Scans HKLM:\SOFTWARE\Microsoft\PolicyManager to evaluate whether MDMWinsOverGP is active,
    and cross-references key enterprise policies against legacy HKLM:\SOFTWARE\Policies to find
    conflicts between Group Policy and Intune.
.PARAMETER ExportHtml
    Optional file path to output an HTML report.
.EXAMPLE
    .\Get-AdminSignalPolicyAudit.ps1
.EXAMPLE
    .\Get-AdminSignalPolicyAudit.ps1 -ExportHtml "C:\Temp\AuditReport.html"
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ExportHtml
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       AdminSignal Policy Precedence & Conflict Auditor   " -ForegroundColor Cyan
Write-Host "       https://adminsignal.com                           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check MDMWinsOverGP
$mdmWinsPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\ControlPolicyConflict"
$mdmWinsDefault = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ControlPolicyConflict\MDMWinsOverGP"

$mdmWinsValue = $null
if (Test-Path $mdmWinsPath) {
    $val = Get-ItemProperty -Path $mdmWinsPath -Name "MDMWinsOverGP" -ErrorAction SilentlyContinue
    if ($null -ne $val.MDMWinsOverGP) { $mdmWinsValue = $val.MDMWinsOverGP }
}

if ($null -eq $mdmWinsValue -and (Test-Path $mdmWinsDefault)) {
    $val = Get-ItemProperty -Path $mdmWinsDefault -Name "value" -ErrorAction SilentlyContinue
    if ($null -ne $val.value) { $mdmWinsValue = $val.value }
}

$mdmWinsStatus = switch ($mdmWinsValue) {
    1 { "ENABLED (MDM / Intune takes precedence over GPO)" }
    0 { "DISABLED (GPO takes precedence over MDM)" }
    default { "NOT CONFIGURED (Default Windows precedence: GPO wins)" }
}

Write-Host "`n[+] MDMWinsOverGP Status: $mdmWinsStatus" -ForegroundColor Yellow

# 2. Check Enrolled MDM Provider Info
$enrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
$enrolledProviders = @()
if (Test-Path $enrollmentPath) {
    Get-ChildItem -Path $enrollmentPath -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if ($props.ProviderID -match "MS DM Server" -or $props.UPN) {
            $enrolledProviders += [PSCustomObject]@{
                EnrollmentID = $_.PSChildName
                UPN          = $props.UPN
                ProviderID   = $props.ProviderID
            }
        }
    }
}

if ($enrolledProviders.Count -gt 0) {
    Write-Host "[+] Active Intune / MDM Enrollments: $($enrolledProviders.Count) detected." -ForegroundColor Green
    foreach ($p in $enrolledProviders) {
        Write-Host "    - Provider: $($p.ProviderID) | UPN: $($p.UPN)" -ForegroundColor Gray
    }
} else {
    Write-Host "[!] No active Intune/MDM enrollment found on this machine." -ForegroundColor Yellow
}

# 3. Check for specific high-conflict policy areas (e.g., Windows Update)
$policyChecklist = @(
    @{
        Area         = "WindowsUpdate"
        Setting      = "DeferFeatureUpdates"
        CspPath      = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
        CspKey       = "DeferFeatureUpdates"
        GpoPath      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        GpoKey       = "DeferFeatureUpdates"
    },
    @{
        Area         = "WindowsUpdate"
        Setting      = "DeferQualityUpdates"
        CspPath      = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
        CspKey       = "DeferQualityUpdates"
        GpoPath      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        GpoKey       = "DeferQualityUpdates"
    },
    @{
        Area         = "WindowsUpdate"
        Setting      = "WUServer (Legacy WSUS vs Cloud)"
        CspPath      = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
        CspKey       = "UpdateServiceUrl"
        GpoPath      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        GpoKey       = "WUServer"
    },
    @{
        Area         = "Defender"
        Setting      = "RealtimeProtection"
        CspPath      = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Defender"
        CspKey       = "AllowRealtimeMonitoring"
        GpoPath      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
        GpoKey       = "DisableRealtimeMonitoring"
    }
)

$auditResults = @()

foreach ($item in $policyChecklist) {
    $cspVal = $null
    $gpoVal = $null

    if (Test-Path $item.CspPath) {
        $props = Get-ItemProperty -Path $item.CspPath -ErrorAction SilentlyContinue
        $cspVal = $props.($item.CspKey)
    }

    if (Test-Path $item.GpoPath) {
        $props = Get-ItemProperty -Path $item.GpoPath -ErrorAction SilentlyContinue
        $gpoVal = $props.($item.GpoKey)
    }

    $conflict = ($null -ne $cspVal -and $null -ne $gpoVal)
    $winner = "None"

    if ($conflict) {
        if ($mdmWinsValue -eq 1) {
            $winner = "Intune (MDMWinsOverGP Active)"
        } else {
            $winner = "GPO (Legacy Default Precedence)"
        }
    } elseif ($null -ne $cspVal) {
        $winner = "Intune (Only Authority Configured)"
    } elseif ($null -ne $gpoVal) {
        $winner = "GPO (Only Authority Configured)"
    }

    $auditResults += [PSCustomObject]@{
        PolicyArea       = $item.Area
        Setting          = $item.Setting
        IntuneCspValue   = if ($null -ne $cspVal) { $cspVal } else { "<Not Set>" }
        GpoValue         = if ($null -ne $gpoVal) { $gpoVal } else { "<Not Set>" }
        HasConflict      = if ($conflict) { "YES" } else { "No" }
        WinningAuthority = $winner
    }
}

Write-Host "`n[+] Policy Comparison Results:" -ForegroundColor Yellow
$auditResults | Format-Table -AutoSize

if ($ExportHtml) {
    $htmlHead = @"
<style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 2rem; background: #0f141c; color: #f0f6fc; }
    h1 { color: #58a6ff; }
    .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-weight: bold; background: #238636; }
    .badge-warn { background: #d29922; color: #000; }
    table { border-collapse: collapse; width: 100%; margin-top: 1.5rem; background: #161b22; }
    th, td { border: 1px solid #30363d; padding: 10px 14px; text-align: left; }
    th { background: #21262d; color: #58a6ff; }
    tr:nth-child(even) { background: #0d1117; }
</style>
"@
    $htmlBody = "<h1>AdminSignal Policy Audit Report</h1>"
    $htmlBody += "<p><strong>Generated:</strong> $(Get-Date)</p>"
    $htmlBody += "<p><strong>MDMWinsOverGP:</strong> $mdmWinsStatus</p>"
    $htmlTable = $auditResults | ConvertTo-Html -Fragment
    $fullHtml = "<!DOCTYPE html><html><head>$htmlHead</head><body>$htmlBody $htmlTable <p><em>Generated by AdminSignal Toolkit &mdash; <a href='https://adminsignal.com' style='color:#58a6ff;'>adminsignal.com</a></em></p></body></html>"
    Set-Content -Path $ExportHtml -Value $fullHtml -Encoding utf8
    Write-Host "[+] HTML Report exported to: $ExportHtml" -ForegroundColor Green
}
