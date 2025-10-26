function Get-PSUUserSession {
    <#
    .SYNOPSIS
        Lists currently logged-in users and their sessions (local or remote).

    .DESCRIPTION
        Retrieves information about users currently logged into the system, including session ID, state, and logon time.
        Supports querying local or remote computers. Credential parameter enables secure remote queries.
        Output includes session details for automation and reporting.

    .PARAMETER ComputerName
        (Optional) The name of the computer(s) to query. Default is the local computer.
        Accepts pipeline input and property binding for automation scenarios.

    .PARAMETER Credential
        (Optional) Credential to use for remote queries. Required for remote computers if not using current user context.
        Accepts [PSCredential] object. Use Get-Credential to create.

    .EXAMPLE
        Get-PSUUserSession

        Lists all currently logged-in users and their session information on the local computer.

    .EXAMPLE
        Get-PSUUserSession -ComputerName "Server01"

        Lists user sessions on Server01 using current user context.

    .EXAMPLE
        $cred = Get-Credential
        Get-PSUUserSession -ComputerName "Server02" -Credential $cred

        Lists user sessions on Server02 using provided credentials.

    .OUTPUTS
        [PSCustomObject]
        Properties include: ComputerName, UserName, SessionName, Id, State, IdleTime, LogonTime

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-03
        Last Modified: 2025-10-26

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    process {
        $computer = $ComputerName
        $localNames = @(
            $env:COMPUTERNAME.ToLower(),
            [System.Net.Dns]::GetHostName().ToLower(),
            [System.Net.Dns]::GetHostEntry('localhost').HostName.ToLower()
        )
        $isLocal = $localNames -contains $computer.ToLower()
        $results = if ($isLocal) {
            query user | Select-Object -Skip 1 | ForEach-Object {
                $parts = $_ -replace '\s{2,}', ',' -split ','
                [PSCustomObject]@{
                    ComputerName = $computer
                    UserName     = $parts[0].Trim().Trim('>')
                    SessionName  = $parts[1].Trim()
                    Id           = $parts[2].Trim()
                    State        = $parts[3].Trim()
                    IdleTime     = $parts[4].Trim()
                    LogonTime    = $parts[5..($parts.Count - 1)] -join ','
                }
            }
        } else {
            $invokeParams = @{ 
                ComputerName = $computer;
                ScriptBlock  = {
                    query user | Select-Object -Skip 1 | ForEach-Object {
                        $parts = $_ -replace '\s{2,}', ',' -split ','
                        [PSCustomObject]@{
                            ComputerName = $env:COMPUTERNAME
                            UserName     = $parts[0].Trim().Trim('>')
                            SessionName  = $parts[1].Trim()
                            Id           = $parts[2].Trim()
                            State        = $parts[3].Trim()
                            IdleTime     = $parts[4].Trim()
                            LogonTime    = $parts[5..($parts.Count - 1)] -join ','
                        }
                    }
                }
            }
            if ($Credential) { $invokeParams.Credential = $Credential }
            Invoke-Command @invokeParams
        }
        $results
    }
}