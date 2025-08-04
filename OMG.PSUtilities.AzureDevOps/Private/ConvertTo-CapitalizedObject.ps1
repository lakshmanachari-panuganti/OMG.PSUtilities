function ConvertTo-CapitalizedObject {
    <#
    .SYNOPSIS
        Converts a collection of hashtables or objects into [PSCustomObject]s with capitalized property names.

    .DESCRIPTION
        This function is useful for reformatting REST API responses into consistent PowerShell objects
        with standardized property names (first letter capitalized).

    .PARAMETER InputObject
        The collection of hashtables or objects to transform.

    .EXAMPLE
        ConvertTo-CapitalizedObject -InputObject $response.value

    .OUTPUTS
        [PSCustomObject[]] with capitalized property names

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2 August 2025: Initial Development

    .LINK
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti/
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject
    )

    process {
        foreach ($item in $InputObject) {
            $obj = @{}

            foreach ($property in $item.PSObject.Properties) {
                $originalName = $property.Name
                $capitalizedName = if ($originalName.Length -gt 1) {
                    ($originalName[0].ToString().ToUpper()) + ($originalName.Substring(1))
                } else {
                    $originalName.ToUpper()
                }

                $obj[$capitalizedName] = $property.Value
            }

            [PSCustomObject]$obj
        }
    }
}