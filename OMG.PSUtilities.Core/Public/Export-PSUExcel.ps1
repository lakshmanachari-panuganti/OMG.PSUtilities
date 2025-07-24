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
    The array of objects to export to Excel.

.PARAMETER ExcelPath
    The path where the Excel file will be saved.

.PARAMETER KeepBackup
    If specified, keeps a backup of the existing Excel file (if any) in a timestamped folder.

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
    Updated: 2025-07-03 - Now supports pipeline input for DataObject and backup handling.
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
        [switch]$AutoFilter
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
                if (Test-Path -Path $ExcelPath) {
                    Remove-Item -Path $ExcelPath -Force
                }
                
            }

            # Export data and return Excel package object
            $excelPackage = $allData | Export-Excel -Path $ExcelPath -WorksheetName Sheet1 -PassThru -AutoSize -ErrorAction Stop

            # Get worksheet
            $ws = $excelPackage.Workbook.Worksheets['Sheet1']

            # Style entire data range
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

            # Header formatting (row 1)
            Set-ExcelRange -Worksheet $ws -Range "1:1" -Bold -BackgroundColor Black -FontColor White

            # Freeze top row
            $ws.View.FreezePanes(2, 1)

            # Save the Excel file
            Close-ExcelPackage $excelPackage -Show:$AutoOpen

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
