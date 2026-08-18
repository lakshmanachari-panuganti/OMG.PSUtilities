function Write-PSUAdoParameterTrace {
    <#
    .SYNOPSIS
        Writes the bound parameters of an Azure DevOps command to the verbose stream.

    .DESCRIPTION
        This private helper function emits the calling command's bound parameters to the verbose
        stream so that automation runs can be traced without exposing secrets. The PAT value is
        always masked to its first three characters.

        Every public Azure DevOps command calls this helper as the first statement of its begin
        block, which keeps the verbose output identical across the module.

    .PARAMETER Invocation
        The calling command's $MyInvocation, used to report the command name being traced.

    .PARAMETER BoundParameters
        The calling command's $PSBoundParameters.

    .OUTPUTS
        None

    .EXAMPLE
        Write-PSUAdoParameterTrace -Invocation $MyInvocation -BoundParameters $PSBoundParameters

        Writes the caller's parameters to the verbose stream with the PAT masked.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 6th August 2026

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.InvocationInfo]$Invocation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$BoundParameters
    )

    Write-Verbose "[$($Invocation.MyCommand.Name)] Parameters:"
    foreach ($param in $BoundParameters.GetEnumerator()) {
        if ($param.Key -eq 'PAT') {
            # Never reveal any part of the token. Leading characters narrow a brute-force
            # search and are enough to correlate a token across logs.
            $maskedPAT = "********"
            Write-Verbose "  $($param.Key): $maskedPAT"
        } else {
            Write-Verbose "  $($param.Key): $($param.Value)"
        }
    }
}
