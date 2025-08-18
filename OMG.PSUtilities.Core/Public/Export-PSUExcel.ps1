function Export-PSUExcel {
    <#
    .SYNOPSIS
        Converts an array of objects to a styled Excel file.

    .DESCRIPTION
        This advanced wrapper around 'Export-Excel' enhances usability, reliability, and presentation for exporting PowerShell data to Excel.

        Key improvements over plain Export-Excel:
        Validates Excel file path and ensures `.xlsx` extension and parent folder exists.
        Adds optional `-KeepBackup` support: backs up existing files in timestamped subfolders.
        Similar to Export-Excel it adds optional `-AutoOpen` switch to open the Excel file after creation. 
        Adds optional `-AutoFilter` switch to enable Excel-style column filters.
        Applies professional formatting:
            • Bold black header with white font
            • LightGray background with borders
            • Calibri font with 10.5pt size
        Automatically freezes the top header row for easier scrolling.
        Supports clean handling of pipeline input, making it easy to integrate into larger reporting scripts.

        Use this function for more visually appealing Excel reports — especially useful in automation, reporting tools, or audit exports.

    .PARAMETER DataObject
        (Mandatory) The array of objects to export to Excel.

    .PARAMETER ExcelPath
        (Mandatory) The path where the Excel file will be saved. Must have .xlsx extension.

    .PARAMETER KeepBackup
        (Optional) Switch parameter to keep a backup of the existing Excel file in a timestamped folder.

    .PARAMETER AutoOpen
        (Optional) Switch parameter to automatically open the Excel file after creation.

    .PARAMETER AutoFilter
        (Optional) Switch parameter to enable Excel-style column filters.

    .PARAMETER WorksheetName
        (Optional) The name of the worksheet within the Excel file where the data will be exported.
        Default value is "Sheet1".

    .PARAMETER Clear
        (Optional) Switch parameter to delete the existing Excel file before writing new data when -WorksheetName is not used.

    .EXAMPLE
        Export-PSUExcel -DataObject $data -ExcelPath 'C:\Reports\report.xlsx'

    .EXAMPLE
        $data | Export-PSUExcel -ExcelPath 'C:\Reports\report.xlsx' -KeepBackup

    .EXAMPLE
        # Export data and automatically open the Excel file after creation
        $data | Export-PSUExcel -ExcelPath 'C:\Reports\report.xlsx' -AutoOpen

    .EXAMPLE
        # Export data with Excel-style column filters enabled
        $data | Export-PSUExcel -ExcelPath 'C:\Reports\report.xlsx' -AutoFilter

    .NOTES
        Author: Lakshmanachari Panuganti
        File Creation Date: 2025-06-27
        Inspired by the author of of ImportExcel Module developper Doug Finke. Thanks to him.
        Updated: 2025-07-03 - Now supports pipeline input for DataObject and backup handling.

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
        https://github.com/dfinke/ImportExcel

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [object[]]$DataObject,

        [Parameter(Mandatory)]
        [ValidateScript({
                if (-not (Test-Path (Split-Path $_ -Parent))) {
                    throw "Parent directory '$(Split-Path $_ -Parent)' does not exist."
                }
                if ([System.IO.Path]::GetExtension($_) -ne ".xlsx") {
                    throw "The file path must have a .xlsx extension."
                }
                return $true
            })]
        [string]$ExcelPath,

        [Parameter()]
        [switch]$KeepBackup,

        [Parameter()]
        [switch]$AutoOpen,

        [Parameter()]
        [switch]$AutoFilter,

        [Parameter()]
        [string]$WorksheetName = "Sheet1",

        [Parameter()]
        [switch]$Clear
    )

    begin {
        $allData = @()
    }
    process {
        if ($null -ne $DataObject) {
            $allData += $DataObject
        }
    }
    end {
        try {
            $parentFolder = Split-Path -Parent $ExcelPath
           
            if ($KeepBackup.IsPresent) {
                if (Test-Path -Path $ExcelPath) {
                    $fileInfo = Get-Item $ExcelPath
                    $timestamp = $fileInfo.LastWriteTime.ToString('yyyyMMdd-HHmmss')
                    $backupFolder = Join-Path -Path $parentFolder -ChildPath ($fileInfo.BaseName)

                    if (-not (Test-Path $backupFolder)) {
                        New-Item -Path $backupFolder -ItemType Directory | Out-Null
                    }

                    $backupFilePath = Join-Path $backupFolder ($fileInfo.BaseName + "-$timestamp.xlsx")
                    Write-Host "Backing up existing file to '$backupFilePath'..." -ForegroundColor Cyan
                    Move-Item -Path $ExcelPath -Destination $backupFilePath -Force
                }
                else {
                    Write-Warning "No existing file found with the name '$ExcelPath'. No backup created."
                }
 
            }
            else {
                if (-not $PSBoundParameters.ContainsKey('WorksheetName') -and (Test-Path -Path $ExcelPath)) {
                    Remove-Item -Path $ExcelPath -Force
                }
            }

            # === Export to Excel ===
            $excelPackage = $allData | Export-Excel `
                -Path $ExcelPath `
                -WorksheetName $WorksheetName `
                -ClearSheet:$Clear `
                -PassThru `
                -AutoSize `
                -ErrorAction Stop

            $ws = $excelPackage.Workbook.Worksheets[$WorksheetName]

            $usedRange = $ws.Dimension.Address

            if ($AutoFilter) {
                $ws.Cells[$usedRange].AutoFilter = $true
            }

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

            Set-ExcelRange -Worksheet $ws -Range "1:1" -Bold -BackgroundColor Black -FontColor White

            $ws.View.FreezePanes(2, 1)

            Close-ExcelPackage $excelPackage -Show:$AutoOpen
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
