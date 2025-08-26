function ConvertTo-QuotedArrayString {
    <#
    .SYNOPSIS
        Converts an array of strings into a PowerShell-formatted quoted array block.

    .DESCRIPTION
        This function takes a string array and converts it into a string representation of a PowerShell array.
        Each item is wrapped in single quotes and placed on a new line with indentation inside an `@()` block.
        Useful for exporting function names in PowerShell Modules or generating reusable code or documentation examples.

    .PARAMETER InputArray
        The array of strings to convert.

    .EXAMPLE
        @('Apple', 'Banana', 'Cherry') | ConvertTo-QuotedArrayString

        Output:
        @(
            'Apple',
            'Banana',
            'Cherry'
        )
    
    .EXAMPLE
        ConvertTo-QuotedArrayString -InputArray @('Apple', 'Banana', 'Cherry')

        Output:
        @(
            'Apple',
            'Banana',
            'Cherry'
        )

    .EXAMPLE
        ConvertTo-QuotedArrayString @('Apple', 'Banana', 'Cherry')

        Output:
        @(
            'Apple',
            'Banana',
            'Cherry'
        )
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(
            Mandatory, 
            ValueFromPipeline
        )]
        [AllowEmptyCollection()]
        [string[]]$InputArray
    )

    begin { 
        $allItems = @() 
    }
    process { 
        $allItems += $InputArray 
    }
    end {
        if ($allItems.Count -eq 0) {
            return '@()'
        }
        $quotedItems = @($allItems | ForEach-Object { "    '$_'," })
        if ($quotedItems.Count -gt 0) {
            $quotedItems[-1] = $quotedItems[-1].TrimEnd(',')
        }
        "@(`n$($quotedItems -join "`n")`n)"
    }
}