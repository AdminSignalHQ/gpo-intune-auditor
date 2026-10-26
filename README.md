# GPO vs. Intune Policy Auditor ⚖️

[![Website](https://img.shields.io/badge/Companion%20Guides-adminsignal.com-0078D4?style=for-the-badge&logo=google-chrome&logoColor=white)](https://adminsignal.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207+-blue?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/AdminSignalHQ/gpo-intune-auditor)

A lightweight PowerShell diagnostic toolkit for Windows administrators to inspect **policy precedence, MDMWinsOverGP enforcement, and Co-Management workload sliders** on Windows 10/11 hybrid-joined endpoints.

Companion code to the in-depth technical analysis at [adminsignal.com](https://adminsignal.com).

---

## 🔍 Why This Tool?

When managing hybrid-joined Windows devices with both **Active Directory Group Policy (GPO)** and **Microsoft Intune (MDM)**:
1. Both authorities frequently configure the exact same underlying Windows registry settings.
2. Even when `MDMWinsOverGP` is configured, certain CSPs behave inconsistently or fall back to GPO if Intune policy is removed (registry tattooing).
3. Co-Management workload sliders in Microsoft Configuration Manager (SCCM) determine which authority has jurisdiction, but administrators often need to verify what the client actually thinks its active authority is.

This toolkit queries local Windows policy registries and decodes Co-Management bitmasks to provide immediate clarity.

---

## 🛠️ Included Tools

### 1. `Get-AdminSignalPolicyAudit.ps1`
Inspects local PolicyManager CSP entries and legacy Group Policy registry trees:
* Evaluates `MDMWinsOverGP` configuration status (Enabled = 1, Disabled = 0, or Not Configured).
* Cross-references Intune CSP values in `HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device` with GPO values in `HKLM:\SOFTWARE\Policies\Microsoft`.
* Flags conflicting settings and indicates the winning authority.
* Supports generating a formatted HTML report with `-ExportHtml`.

#### Usage:
`powershell
# Run a console audit
.\Get-AdminSignalPolicyAudit.ps1

# Run audit and generate an HTML report
.\Get-AdminSignalPolicyAudit.ps1 -ExportHtml "C:\Temp\PolicyAuditReport.html"
`

---

### 2. `Get-CoManagementSliders.ps1`
Decodes the local Configuration Manager client Co-Management bitmask (CoManagementFlags) to display the exact status of each workload slider without needing console access:

* **Compliance Policies**
* **Device Configuration / Resource Access**
* **Endpoint Protection**
* **Client Apps**
* **Office Click-to-Run Apps**
* **Windows Update for Business**
* **Endpoint Analytics**

#### Usage:
`powershell
.\Get-CoManagementSliders.ps1
`

Sample output:
`	ext
Workload                 Authority   BitValue  Status
--------                 ---------   --------  ------
CompliancePolicies       Intune      1         Managed by Intune
ResourceAccess           ConfigMgr   2         Managed by ConfigMgr
EndpointProtection       Intune      4         Managed by Intune
ClientApps               ConfigMgr   8         Managed by ConfigMgr
OfficeClickToRun         ConfigMgr   16        Managed by ConfigMgr
WindowsUpdate            Intune      32        Managed by Intune
EndpointAnalytics        Intune      64        Managed by Intune
`

---

## 📖 Deep Dive Reading on AdminSignal

* [GPO vs. Intune Precedence: How MDMWinsOverGP Truly Behaves](https://adminsignal.com)
* [Demystifying the Co-Management Workload Slider Bitmasks](https://adminsignal.com)
* [Preventing Registry Tattooing during Modern Management Migrations](https://adminsignal.com)
