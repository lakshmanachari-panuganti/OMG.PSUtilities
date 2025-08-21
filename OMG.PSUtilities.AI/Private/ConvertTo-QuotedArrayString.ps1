<#
.SYNOPSIS
    Converts an array of strings into a PowerShell-formatted quoted array block.

.DESCRIPTION
    This function takes a string array and converts it into a string representation of a PowerShell array.
    Each item is wrapped in single quotes and placed on a new line with indentation inside an `@()` block.
    Useful for generating reusable code or documentation examples.

.PARAMETER InputArray
    The array of strings to convert.

.EXAMPLE
    @('Apple', 'Banana', 'Cherry') | ConvertTo-QuotedArrayString

    Output:
    @(
        'Apple'
        'Banana'
        'Cherry'
    )

#>
function ConvertTo-QuotedArrayString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [string]$InputArray
    )

    begin {
        $allItems = @()
    }
    process {
        $allItems += $InputArray
    }
    end {
        $quotedItems = $allItems | ForEach-Object { "    '$_'," }
        # Remove the trailing comma from the last item
        if ($quotedItems.Count -gt 0) {
            $quotedItems[-1] = $quotedItems[-1].TrimEnd(',')
        }
        $result = "@(`n" + ($quotedItems -join "`n") + "`n)"
        $result
    }
}
