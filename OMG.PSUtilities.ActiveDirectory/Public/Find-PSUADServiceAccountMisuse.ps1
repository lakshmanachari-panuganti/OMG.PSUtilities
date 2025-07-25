function Find-PSUADServiceAccountMisuse {
    <#
    .SYNOPSIS
        Identifies potential misuse of service accounts by detecting interactive logon events in AD.

    .DESCRIPTION
        This function searches for Active Directory user accounts that resemble service accounts (e.g., contain "svc", "sql", etc.),
        and checks if these accounts have interactive logon events (Event ID 4624 with LogonType 2, 10, or 11) over a user-defined period.
        It flags accounts that may indicate risk and outputs results optionally to the console and/or CSV file.

        Returns an array of psobject with properties: SamAccountName, LogonCount, RiskScore, RiskLevel, LastLogon, Description

    .PARAMETER DaysBack
        Number of days to look back in security event logs. Default is 7.

    .PARAMETER Credential
        Optional. Use alternate credentials for AD and event log queries.

    .PARAMETER Detailed
        Switch. If specified, returns detailed login events.

    .PARAMETER ExportPath
        Optional path to export results to CSV.

    .PARAMETER IncludeBuiltin
        Switch. If specified, includes built-in service accounts like "LOCAL SERVICE", "NETWORK SERVICE" etc.

    .PARAMETER Filter
        Optional string filter to apply to user names (e.g., '*svc').

    .PARAMETER Server
        Optional if you running the function on the domain controler itself. or else pass the AD server or DC.
    .OUTPUTS
        PSCustomObject[]

    .EXAMPLE
        Find-PSUADServiceAccountMisuse -DaysBack 14 -Detailed -ExportPath "ADServiceAccountMisuse.csv"

    .NOTES
        Author : Lakshmanachari Panuganti
        Date: 29 June 2025
        TODO: Add the server names where its  used.
    #>

    [CmdletBinding()]
    param (
        [int]$DaysBack = 7,
        [PSCredential]$Credential,
        [switch]$Detailed,
        [string]$ExportPath,
        [switch]$IncludeBuiltin,
        [string]$Filter = '*',
        [string]$Server = $env:COMPUTERNAME # Should be a domain controler
    )

    Write-Host "[+] Starting AD service account misuse detection..." -ForegroundColor Cyan
    $StartDate = (Get-Date).AddDays(-$DaysBack)
    $EndDate = Get-Date

    $SearchFilter = { Name -like $Filter }
    $ADUsers = if ($Credential) {
        Get-ADUser -Filter $SearchFilter -Credential $Credential -Properties *
    } else {
        Get-ADUser -Filter $SearchFilter -Properties *
    }

    $ServiceAccountPatterns = @('svc', 'sql', 'ora', 'ftp', 'backup', 'sa_', '_svc', 'report')
    $BuiltInAccounts = @('LOCAL SERVICE', 'NETWORK SERVICE', 'SYSTEM')
    $InteractiveLogonTypes = @(2, 10, 11)

    Write-Progress -Activity "Collecting Event Logs..." -Status "Scanning event logs for logon activity..."
    $AllLogonEvents = Get-WinEvent -ComputerName $Server -Credential $Credential -FilterHashtable @{
        LogName = 'Security'; ID = 4624; StartTime = $StartDate; EndTime = $EndDate
    } -ErrorAction SilentlyContinue | Where-Object {
        $_.Properties[8].Value -in $InteractiveLogonTypes
    }

    $Results = @()

    foreach ($Account in $ADUsers) {
        $Username = $Account.SamAccountName

        if (-not $IncludeBuiltin -and ($BuiltInAccounts -contains $Username)) {
            continue
        }

        if (-not ($ServiceAccountPatterns | Where-Object { $Username -like "*$_*" })) {
            continue
        }

        $UserEvents = $AllLogonEvents | Where-Object {
            $_.Properties[5].Value -eq $Username
        }

        $LogonCount = $UserEvents.Count
        $RiskScore = switch ($LogonCount) {
            { $_ -ge 10 } { 10 }
            { $_ -ge 5 }  { 5 }
            { $_ -ge 1 }  { 3 }
            default       { 0 }
        }

        $RiskLevel = switch ($RiskScore) {
            { $_ -ge 10 } { "High" }
            { $_ -ge 5 }  { "Medium" }
            { $_ -ge 1 }  { "Low" }
            default       { "None" }
        }

        $Object = [PSCustomObject]@{
            SamAccountName     = $Username
            DisplayName        = $Account.DisplayName
            Enabled            = $Account.Enabled
            LogonCount         = $LogonCount
            RiskScore          = $RiskScore
            RiskLevel          = $RiskLevel
            LastLogonDate      = $Account.LastLogonDate
            Description        = $Account.Description
            DistinguishedName  = $Account.DistinguishedName
            DetailedLoginEvents = if ($Detailed) { $UserEvents } else { $null }
        }

        $Results += $Object
    }

    Write-Host "[+] Analyzed $($Results.Count) accounts" -ForegroundColor Green
    $Results | Format-Table SamAccountName, LogonCount, RiskLevel, LastLogonDate -AutoSize

    if ($ExportPath) {
        $Results | Select-Object * -ExcludeProperty DetailedLoginEvents | Export-PSUExcel -ExcelPath "$ExportPath\ADServiceAccountMisuse.xlsx"
        $Results | ConvertTo-Json -Depth 50 | Out-File -FilePath "$ExportPath\ADServiceAccountMisuse.Json"
        Write-Host "[+] Results exported to $ExportPath" -ForegroundColor Yellow
        Write-Host "   [+] \ADServiceAccountMisuse.xlsx" -ForegroundColor Yellow
        Write-Host "   [+] \ADServiceAccountMisuse.Json" -ForegroundColor Yellow
    }

    return $Results
}