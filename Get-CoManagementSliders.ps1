<#
.SYNOPSIS
    Decodes the Microsoft Configuration Manager (SCCM) Co-Management workload flags.
.DESCRIPTION
    Reads the client-side CoManagementFlags bitmask from HKLM:\SOFTWARE\Microsoft\CCM
    or the DeviceManageabilityCSP registry hive, decoding whether each workload is
    managed by Configuration Manager or Microsoft Intune.
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       AdminSignal Co-Management Slider Bitmask Decoder    " -ForegroundColor Cyan
Write-Host "       https://adminsignal.com                           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$regPathCCM = "HKLM:\SOFTWARE\Microsoft\CCM"
$flags = $null

if (Test-Path $regPathCCM) {
    $props = Get-ItemProperty -Path $regPathCCM -Name "CoManagementFlags" -ErrorAction SilentlyContinue
    if ($null -ne $props.CoManagementFlags) {
        $flags = [int]$props.CoManagementFlags
    }
}

if ($null -eq $flags) {
    # Fallback to DeviceManageabilityCSP
    $cspPath = "HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server"
    if (Test-Path $cspPath) {
        $props = Get-ItemProperty -Path $cspPath -Name "CoMgmtSettingsProd" -ErrorAction SilentlyContinue
        if ($null -ne $props.CoMgmtSettingsProd) {
            $flags = [int]$props.CoMgmtSettingsProd
        }
    }
}

if ($null -eq $flags) {
    Write-Warning "Device does not appear to be Co-Managed (Neither ConfigMgr CoManagementFlags nor CoMgmtSettingsProd were found)."
    exit 0
}

Write-Host "`n[+] Detected Raw Co-Management Bitmask: $flags (Hex: 0x$($flags.ToString('X')))" -ForegroundColor Yellow

$workloadDefinitions = @(
    @{ Name = "CompliancePolicies";  Bit = 1;   Desc = "Compliance Policies" }
    @{ Name = "ResourceAccess";      Bit = 2;   Desc = "Device Configuration / Resource Access" }
    @{ Name = "EndpointProtection";  Bit = 4;   Desc = "Endpoint Protection (Defender / Firewall)" }
    @{ Name = "ClientApps";          Bit = 8;   Desc = "Client / Modern Applications" }
    @{ Name = "OfficeClickToRun";    Bit = 16;  Desc = "Microsoft 365 Apps (Office Click-to-Run)" }
    @{ Name = "WindowsUpdate";       Bit = 32;  Desc = "Windows Update Policies (WUfB)" }
    @{ Name = "EndpointAnalytics";   Bit = 64;  Desc = "Endpoint Analytics" }
)

$results = foreach ($w in $workloadDefinitions) {
    $isIntune = (($flags -band $w.Bit) -eq $w.Bit)
    [PSCustomObject]@{
        Workload     = $w.Desc
        BitValue     = $w.Bit
        Authority    = if ($isIntune) { "Intune" } else { "ConfigMgr" }
        Status       = if ($isIntune) { "Managed by Microsoft Intune" } else { "Managed by Configuration Manager" }
    }
}

$results | Format-Table -AutoSize
Write-Host "`nFor full details on transitioning sliders safely, visit https://adminsignal.com" -ForegroundColor Cyan
