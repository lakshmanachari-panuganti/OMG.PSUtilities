
function ConvertTo-ExcelFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$DataObject,

        [Parameter(Mandatory)]
        [string]$ExcelPath
    )

    try {
        # Export data and return Excel package object
        $excelPackage = $DataObject | Export-Excel -Path $ExcelPath -WorksheetName Sheet1 -AutoSize -PassThru -ErrorAction Stop

        # Get worksheet
        $ws = $excelPackage.Workbook.Worksheets['Sheet1']

        # Style entire data range
        $usedRange = $ws.Dimension.Address
        $rangeStyle = @{
            Worksheet       = $ws
            Range           = $usedRange
            BorderAround    = 'Thick'
            BorderBottom    = 'Thin'
            BorderTop       = 'Thin'
            BorderLeft      = 'Thin'
            BorderRight     = 'Thin'
            FontName        = 'Calibri'
            FontSize        = 10.5
            AutoSize        = $true
            BackgroundColor = 'LightGray'
        }
        Set-ExcelRange @rangeStyle

        # Header formatting (row 1)
        Set-ExcelRange -Worksheet $ws -Range "1:1" -Bold -BackgroundColor Black -FontColor White

        # Freeze top row
        $ws.View.FreezePanes(2, 1)

        # Save the Excel file
        Close-ExcelPackage $excelPackage
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
