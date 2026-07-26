<#
.SYNOPSIS
    Generates a styled HTML dashboard from Azure App Registration audit CSV output.

.DESCRIPTION
    Reads the master audit CSV and bucket CSVs produced by Invoke-PSUAzureAppRegAudit,
    then generates a self-contained HTML file with:
    - Executive summary cards (total apps, 4 bucket counts, ownership stats)
    - Risk flags section (privileged roles, broad permissions, expired secrets)
    - Usage signal coverage breakdown
    - Sortable tables for each bucket
    - Managed Identity summary (if MI CSV exists)

    The HTML file is fully self-contained (inline CSS, no external dependencies)
    and can be shared via email or opened in any browser.

.PARAMETER InputDirectory
    Path to the audit output folder containing the CSV files.

.PARAMETER TenantId
    (Optional) Tenant ID to include in the report header.
    Auto-detected from CSV filenames if omitted.

.PARAMETER OutputFileName
    (Optional) Name of the HTML output file.
    Default is AuditReport_<TenantId>_<Date>.html.

.EXAMPLE
    .\ConvertTo-AuditHtmlReport.ps1 -InputDirectory "C:\AuditOutput\AppRegAudit_abc123_20260307_100000"

    Generates an HTML report from the audit CSVs in the specified folder.

.EXAMPLE
    .\ConvertTo-AuditHtmlReport.ps1 -InputDirectory "C:\AuditOutput\Run1" -TenantId "abc-123"

    Generates an HTML report with explicit tenant ID.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$InputDirectory,

    [Parameter()]
    [string]$TenantId,

    [Parameter()]
    [string]$OutputFileName
)

$ErrorActionPreference = "Stop"

#region Locate CSV files
$masterCsv = Get-ChildItem -Path $InputDirectory -Filter "MasterAudit_Full_*.csv" | Select-Object -First 1
if ($null -eq $masterCsv) {
    throw "Master audit CSV not found in: $InputDirectory"
}

$bucket1Csv = Get-ChildItem -Path $InputDirectory -Filter "Bucket1_SafeToDisable_*.csv"      | Select-Object -First 1
$bucket2Csv = Get-ChildItem -Path $InputDirectory -Filter "Bucket2_NeedsInvestigation_*.csv" | Select-Object -First 1
$bucket3Csv = Get-ChildItem -Path $InputDirectory -Filter "Bucket3_LikelyActive_*.csv"       | Select-Object -First 1
$bucket4Csv = Get-ChildItem -Path $InputDirectory -Filter "Bucket4_BusinessCritical_*.csv"    | Select-Object -First 1
$miCsv      = Get-ChildItem -Path $InputDirectory -Filter "ManagedIdentity_Audit_*.csv"      | Select-Object -First 1

# Auto-detect TenantId from filename
if ([string]::IsNullOrWhiteSpace($TenantId)) {
    if ($masterCsv.Name -match "MasterAudit_Full_(.+?)_\d{8}\.csv") {
        $TenantId = $Matches[1]
    } else {
        $TenantId = "Unknown"
    }
}

$dateStamp = Get-Date -Format "yyyyMMdd"
if ([string]::IsNullOrWhiteSpace($OutputFileName)) {
    $OutputFileName = "AuditReport_${TenantId}_${dateStamp}.html"
}
$outputPath = Join-Path $InputDirectory $OutputFileName
#endregion

#region Import CSVs
Write-Host "  Loading master audit CSV ($($masterCsv.Name))..." -ForegroundColor DarkGray
$masterData  = Import-Csv -Path $masterCsv.FullName

$bucket1Data = if ($bucket1Csv) { Import-Csv -Path $bucket1Csv.FullName } else { @() }
$bucket2Data = if ($bucket2Csv) { Import-Csv -Path $bucket2Csv.FullName } else { @() }
$bucket3Data = if ($bucket3Csv) { Import-Csv -Path $bucket3Csv.FullName } else { @() }
$bucket4Data = if ($bucket4Csv) { Import-Csv -Path $bucket4Csv.FullName } else { @() }
$miData      = if ($miCsv)      { Import-Csv -Path $miCsv.FullName }      else { @() }
#endregion

#region Compute Statistics
$totalApps      = $masterData.Count
$b1Count        = @($bucket1Data).Count
$b2Count        = @($bucket2Data).Count
$b3Count        = @($bucket3Data).Count
$b4Count        = @($bucket4Data).Count
$miCount        = @($miData).Count

$withOwner      = @($masterData | Where-Object { $_.HasOwner -eq "True" }).Count
$withoutOwner   = @($masterData | Where-Object { $_.HasOwner -ne "True" }).Count

$highConf       = @($masterData | Where-Object { $_.UsageConfidence -eq "High" }).Count
$medConf        = @($masterData | Where-Object { $_.UsageConfidence -eq "Medium" }).Count
$lowConf        = @($masterData | Where-Object { $_.UsageConfidence -eq "Low" }).Count

$privEntra      = @($masterData | Where-Object { $_.HasPrivilegedEntraRole -eq "True" }).Count
$privAzure      = @($masterData | Where-Object { $_.HasPrivilegedAzureRole -eq "True" }).Count
$broadPerms     = @($masterData | Where-Object { $_.HasBroadGraphPermissions -eq "True" }).Count
$expiredSecrets = @($masterData | Where-Object { $_.HasExpiredSecret -eq "True" }).Count
$oldSecrets     = @($masterData | Where-Object { [int]($_.OldestSecretAgeDays) -gt 365 }).Count
$legacyAuth     = @($masterData | Where-Object { $_.LegacyAuthDetected -eq "True" }).Count
$microsoftApps  = @($masterData | Where-Object { $_.IsMicrosoftApp -eq "True" }).Count
$withDaemon     = @($masterData | Where-Object { $_.DaemonUsageDetected -eq "True" }).Count
$withExternal   = @($masterData | Where-Object { $_.UsedByExternalSystem -eq "True" }).Count
$withConsumers  = @($masterData | Where-Object { [int]($_.ConsumedByAppsCount) -gt 0 }).Count
$noSP           = @($masterData | Where-Object { $_.NoServicePrincipal -eq "True" }).Count
#endregion

#region Helper: Build HTML table rows
function ConvertTo-HtmlTableRows {
    param(
        [object[]]$Data,
        [string[]]$Columns
    )
    $rows = [System.Text.StringBuilder]::new()
    foreach ($row in $Data) {
        [void]$rows.Append("<tr>")
        foreach ($col in $Columns) {
            $val = $row.$col ?? ""
            # Truncate long values
            if ($val.Length -gt 80) { $val = $val.Substring(0, 77) + "..." }
            [void]$rows.Append("<td>$([System.Web.HttpUtility]::HtmlEncode($val))</td>")
        }
        [void]$rows.Append("</tr>`n")
    }
    return $rows.ToString()
}

function ConvertTo-HtmlTableHeader {
    param([string[]]$Columns)
    $header = "<tr>"
    foreach ($col in $Columns) {
        $header += "<th>$([System.Web.HttpUtility]::HtmlEncode($col))</th>"
    }
    $header += "</tr>"
    return $header
}
#endregion

#region Define bucket table columns
$bucketColumns = @(
    "AppName", "AppId", "DeletionSafetyScore", "BucketLabel", "RecommendedAction",
    "OwnerUPNs", "LastUsedDate", "UsageConfidence", "AuthMethod",
    "CreatedDate", "AppAgeDays", "IsMicrosoftApp"
)

$miColumns = @(
    "DisplayName", "ServicePrincipalId", "AppId", "ManagedIdentityType",
    "LinkedResource", "IsEnabled", "AzureRBACRoles", "DirectoryRoles",
    "HasPrivilegedAzureRole", "HasPrivilegedEntraRole", "PossiblyOrphaned"
)
#endregion

#region Build HTML
$reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure App Registration Audit Report - $TenantId</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; color: #333; line-height: 1.6; }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        h1 { color: #0078d4; margin-bottom: 5px; font-size: 24px; }
        h2 { color: #333; margin: 30px 0 15px; font-size: 20px; border-bottom: 2px solid #0078d4; padding-bottom: 5px; }
        h3 { color: #555; margin: 20px 0 10px; font-size: 16px; }
        .header { background: linear-gradient(135deg, #0078d4, #005a9e); color: white; padding: 25px 30px; border-radius: 8px; margin-bottom: 25px; }
        .header h1 { color: white; font-size: 28px; }
        .header p { color: #cce4f7; font-size: 14px; margin-top: 5px; }
        .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 25px; }
        .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); text-align: center; }
        .card .number { font-size: 36px; font-weight: bold; }
        .card .label { font-size: 13px; color: #666; margin-top: 5px; }
        .card.red .number { color: #d32f2f; }
        .card.orange .number { color: #f57c00; }
        .card.yellow .number { color: #fbc02d; }
        .card.green .number { color: #388e3c; }
        .card.blue .number { color: #0078d4; }
        .card.gray .number { color: #757575; }
        .section { background: white; border-radius: 8px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 10px; }
        .stat-item { display: flex; justify-content: space-between; padding: 8px 12px; background: #f9f9f9; border-radius: 4px; }
        .stat-item .stat-label { color: #555; }
        .stat-item .stat-value { font-weight: 600; }
        .stat-item .stat-value.risk { color: #d32f2f; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }
        th { background: #0078d4; color: white; padding: 10px 8px; text-align: left; position: sticky; top: 0; cursor: pointer; user-select: none; white-space: nowrap; }
        th:hover { background: #005a9e; }
        td { padding: 8px; border-bottom: 1px solid #eee; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        tr:hover { background: #f0f7ff; }
        tr:nth-child(even) { background: #fafafa; }
        tr:nth-child(even):hover { background: #f0f7ff; }
        .table-wrapper { overflow-x: auto; max-height: 500px; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; }
        .bucket-header { display: flex; align-items: center; gap: 10px; }
        .bucket-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; color: white; }
        .bucket-badge.b1 { background: #d32f2f; }
        .bucket-badge.b2 { background: #f57c00; }
        .bucket-badge.b3 { background: #fbc02d; color: #333; }
        .bucket-badge.b4 { background: #388e3c; }
        .footer { text-align: center; color: #999; font-size: 12px; margin-top: 30px; padding: 15px; }
        .collapsible { cursor: pointer; }
        .collapsible-content { display: none; }
        .collapsible-content.active { display: block; }
        @media print { .table-wrapper { max-height: none; overflow: visible; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Azure App Registration Audit Report</h1>
            <p>Tenant: $TenantId | Generated: $reportDate | Total Apps: $totalApps</p>
        </div>

        <!-- Executive Summary Cards -->
        <div class="cards">
            <div class="card blue">
                <div class="number">$totalApps</div>
                <div class="label">Total App Registrations</div>
            </div>
            <div class="card red">
                <div class="number">$b1Count</div>
                <div class="label">Bucket 1 - Safe to Disable</div>
            </div>
            <div class="card orange">
                <div class="number">$b2Count</div>
                <div class="label">Bucket 2 - Needs Investigation</div>
            </div>
            <div class="card yellow">
                <div class="number">$b3Count</div>
                <div class="label">Bucket 3 - Likely Active</div>
            </div>
            <div class="card green">
                <div class="number">$b4Count</div>
                <div class="label">Bucket 4 - Business Critical</div>
            </div>
            <div class="card gray">
                <div class="number">$miCount</div>
                <div class="label">Managed Identities</div>
            </div>
        </div>

        <!-- Risk Flags & Statistics -->
        <div class="section">
            <h2>Risk Flags & Statistics</h2>
            <div class="stat-grid">
                <div class="stat-item"><span class="stat-label">Privileged Entra Roles</span><span class="stat-value$(if ($privEntra -gt 0) {' risk'})">$privEntra</span></div>
                <div class="stat-item"><span class="stat-label">Privileged Azure Roles</span><span class="stat-value$(if ($privAzure -gt 0) {' risk'})">$privAzure</span></div>
                <div class="stat-item"><span class="stat-label">Broad Graph Permissions</span><span class="stat-value$(if ($broadPerms -gt 0) {' risk'})">$broadPerms</span></div>
                <div class="stat-item"><span class="stat-label">Expired Secrets</span><span class="stat-value$(if ($expiredSecrets -gt 0) {' risk'})">$expiredSecrets</span></div>
                <div class="stat-item"><span class="stat-label">Secrets > 1yr Old</span><span class="stat-value$(if ($oldSecrets -gt 0) {' risk'})">$oldSecrets</span></div>
                <div class="stat-item"><span class="stat-label">Legacy Auth Detected</span><span class="stat-value$(if ($legacyAuth -gt 0) {' risk'})">$legacyAuth</span></div>
                <div class="stat-item"><span class="stat-label">No Service Principal</span><span class="stat-value">$noSP</span></div>
                <div class="stat-item"><span class="stat-label">Microsoft 1st-Party Apps</span><span class="stat-value">$microsoftApps</span></div>
            </div>
        </div>

        <!-- Ownership & Usage -->
        <div class="section">
            <h2>Ownership & Usage Signal Coverage</h2>
            <div class="stat-grid">
                <div class="stat-item"><span class="stat-label">Apps With Owners</span><span class="stat-value">$withOwner</span></div>
                <div class="stat-item"><span class="stat-label">Apps Without Owners</span><span class="stat-value$(if ($withoutOwner -gt 0) {' risk'})">$withoutOwner</span></div>
                <div class="stat-item"><span class="stat-label">High Confidence (Active)</span><span class="stat-value">$highConf</span></div>
                <div class="stat-item"><span class="stat-label">Medium Confidence</span><span class="stat-value">$medConf</span></div>
                <div class="stat-item"><span class="stat-label">Low Confidence (No Signal)</span><span class="stat-value$(if ($lowConf -gt 0) {' risk'})">$lowConf</span></div>
                <div class="stat-item"><span class="stat-label">Daemon Usage Detected</span><span class="stat-value">$withDaemon</span></div>
                <div class="stat-item"><span class="stat-label">External CI/CD Systems</span><span class="stat-value">$withExternal</span></div>
                <div class="stat-item"><span class="stat-label">Consumed by Other Apps</span><span class="stat-value">$withConsumers</span></div>
            </div>
        </div>

        <!-- Bucket 1 Table -->
        <div class="section">
            <div class="bucket-header">
                <h2>Bucket 1 - Safe to Disable</h2>
                <span class="bucket-badge b1">$b1Count apps</span>
            </div>
            <p style="color:#666; margin-bottom:10px;">Score 80-100. Safe to disable the Service Principal now. Delete after 30-day soak.</p>
            <div class="table-wrapper">
                <table>
                    $(ConvertTo-HtmlTableHeader -Columns $bucketColumns)
                    $(ConvertTo-HtmlTableRows -Data $bucket1Data -Columns $bucketColumns)
                </table>
            </div>
        </div>

        <!-- Bucket 2 Table -->
        <div class="section">
            <div class="bucket-header">
                <h2>Bucket 2 - Needs Investigation</h2>
                <span class="bucket-badge b2">$b2Count apps</span>
            </div>
            <p style="color:#666; margin-bottom:10px;">Score 50-79. Send to app owner for review. Investigate usage signals.</p>
            <div class="table-wrapper">
                <table>
                    $(ConvertTo-HtmlTableHeader -Columns $bucketColumns)
                    $(ConvertTo-HtmlTableRows -Data $bucket2Data -Columns $bucketColumns)
                </table>
            </div>
        </div>

        <!-- Bucket 3 Table -->
        <div class="section">
            <div class="bucket-header">
                <h2>Bucket 3 - Likely Active</h2>
                <span class="bucket-badge b3">$b3Count apps</span>
            </div>
            <p style="color:#666; margin-bottom:10px;">Score 20-49. Do not touch. Gather more evidence in next audit cycle.</p>
            <div class="table-wrapper">
                <table>
                    $(ConvertTo-HtmlTableHeader -Columns $bucketColumns)
                    $(ConvertTo-HtmlTableRows -Data $bucket3Data -Columns $bucketColumns)
                </table>
            </div>
        </div>

        <!-- Bucket 4 Table -->
        <div class="section">
            <div class="bucket-header">
                <h2>Bucket 4 - Business Critical</h2>
                <span class="bucket-badge b4">$b4Count apps</span>
            </div>
            <p style="color:#666; margin-bottom:10px;">Score 0-19. Never touch without a formal change request and approval.</p>
            <div class="table-wrapper">
                <table>
                    $(ConvertTo-HtmlTableHeader -Columns $bucketColumns)
                    $(ConvertTo-HtmlTableRows -Data $bucket4Data -Columns $bucketColumns)
                </table>
            </div>
        </div>

        <!-- Managed Identities Table -->
        $(if ($miCount -gt 0) { @"
        <div class="section">
            <div class="bucket-header">
                <h2>Managed Identities</h2>
                <span class="bucket-badge" style="background:#0078d4;">$miCount MIs</span>
            </div>
            <p style="color:#666; margin-bottom:10px;">Governance snapshot. Check PossiblyOrphaned = True for MIs with no role assignments.</p>
            <div class="table-wrapper">
                <table>
                    $(ConvertTo-HtmlTableHeader -Columns $miColumns)
                    $(ConvertTo-HtmlTableRows -Data $miData -Columns $miColumns)
                </table>
            </div>
        </div>
"@ })

        <div class="footer">
            <p>Generated by OMG.PSUtilities.AzureCore | Invoke-PSUAzureAppRegAudit v1.0 | $reportDate</p>
            <p>This report is a point-in-time snapshot. No automatic deletions occur. All actions require human review.</p>
        </div>
    </div>

    <script>
        // Simple table sorting
        document.querySelectorAll('th').forEach(th => {
            th.addEventListener('click', () => {
                const table = th.closest('table');
                const tbody = table.querySelector('tbody') || table;
                const rows = Array.from(tbody.querySelectorAll('tr')).slice(1);
                const idx = Array.from(th.parentNode.children).indexOf(th);
                const asc = th.dataset.sort !== 'asc';
                th.dataset.sort = asc ? 'asc' : 'desc';
                rows.sort((a, b) => {
                    const aVal = a.children[idx]?.textContent || '';
                    const bVal = b.children[idx]?.textContent || '';
                    const aNum = parseFloat(aVal);
                    const bNum = parseFloat(bVal);
                    if (!isNaN(aNum) && !isNaN(bNum)) return asc ? aNum - bNum : bNum - aNum;
                    return asc ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
                });
                rows.forEach(r => tbody.appendChild(r));
            });
        });
    </script>
</body>
</html>
"@

# Write HTML file
$html | Out-File -FilePath $outputPath -Encoding UTF8 -Force
Write-Host "  HTML Report: $outputPath" -ForegroundColor Green
Write-Host "  Report size: $([math]::Round((Get-Item $outputPath).Length / 1KB, 1)) KB" -ForegroundColor DarkGray
#endregion
