<#
.SYNOPSIS
    Executes a Graph API call with automatic retry on throttling (HTTP 429).

.DESCRIPTION
    Wraps a scriptblock containing a Microsoft Graph SDK call and automatically
    retries on HTTP 429 (Too Many Requests) responses. Uses the Retry-After header
    when available, otherwise waits a default of 30 seconds between retries.

    This function is used internally by Invoke-PSUAzureAppRegAudit to handle
    throttle protection during bulk data collection.

.PARAMETER ScriptBlock
    The scriptblock containing the Graph API call to execute.

.PARAMETER OperationName
    A descriptive name for the operation, used in log messages.
    Default is "GraphCall".

.PARAMETER MaxRetries
    The maximum number of retry attempts on throttle (429) responses.
    Default is 3.

.PARAMETER LogFunction
    An optional scriptblock that accepts (Level, Signal, Message) for logging.
    If not provided, writes to the console via Write-Warning.

.EXAMPLE
    Invoke-PSUGraphWithRetry -OperationName "BulkLoadApps" -ScriptBlock {
        Get-MgApplication -All
    }

    Executes Get-MgApplication -All with retry protection.

.OUTPUTS
    [System.Object] The result of the scriptblock, or $null if all retries fail.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>
function Invoke-PSUGraphWithRetry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [string]$OperationName = "GraphCall",

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [scriptblock]$LogFunction
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] OperationName = $OperationName, MaxRetries = $MaxRetries"
    }

    process {
        $attempt = 0
        while ($attempt -lt $MaxRetries) {
            try {
                return & $ScriptBlock
            } catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                if ($statusCode -eq 429) {
                    $retryAfter = 30
                    try { $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"] } catch {}
                    $msg = "Throttled. Waiting ${retryAfter}s (attempt $($attempt + 1)/$MaxRetries)"
                    if ($null -ne $LogFunction) {
                        & $LogFunction "WARN" $OperationName $msg
                    } else {
                        Write-Warning "[$OperationName] $msg"
                    }
                    Start-Sleep -Seconds $retryAfter
                    $attempt++
                } else {
                    $msg = "HTTP $statusCode - $($_.Exception.Message)"
                    if ($null -ne $LogFunction) {
                        & $LogFunction "ERROR" $OperationName $msg
                    } else {
                        Write-Warning "[$OperationName] $msg"
                    }
                    return $null
                }
            }
        }
        $msg = "Failed after $MaxRetries retries. Returning null."
        if ($null -ne $LogFunction) {
            & $LogFunction "ERROR" $OperationName $msg
        } else {
            Write-Warning "[$OperationName] $msg"
        }
        return $null
    }
}
