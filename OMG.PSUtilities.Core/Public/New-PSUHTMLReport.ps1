Function New-PSUHTMLReport {
  <#
  .SYNOPSIS
    Creates an HTML report as PowerShell object.

  .DESCRIPTION
    Creates an HTML report as PowerShell object.
    This HTML report is basically a table or list that is added with formatted pre-content.

  .PARAMETER PSObject
    It is a PScustomobject to create the report with.

  .PARAMETER ConditionalForegroundColor
    Same Text in all cells is formatted with a custom font color based on condition.
    It should be hashtable. KEY represents the text. VALUE represents the color of the text.

  .PARAMETER PreContent
    Pre content for the report.

  .PARAMETER PreContentColor
    Colour for the pre content. Default color for the pre content is Black.

  .PARAMETER PreContentBold
    This switch makes the pre content as bold.

  .PARAMETER PreContentItalic
    This switch makes the pre content as Italic.

  .PARAMETER Type
    To create the report as table or List.

  .EXAMPLE
    $ServiceParams = @{
      PSObject = Get-Service | Select-Object Name, Displayname, Status -First 5
      PreContent = 'Below is the list of first 5 services'
      PreContentColor = 'Blue'
      PreContentBold = $true
      PreContentItalic = $true
      As = 'Table'
    }
    $ServicesHtml = New-PSUHTMLReport @ServiceParams

  .OUTPUTS
    <p><font color = Blue><i><b>Below is the list of first 5 services</b></i></font></p>
    <table>
      <colgroup><col/><col/><col/></colgroup>
      <tr><th>Name</th><th>DisplayName</th><th>Status</th></tr>
      <tr><td>AbtSvcHost</td><td>AbtSvcHost</td><td>Running</td></tr>
      <tr><td>AdobeARMservice</td><td>Adobe Acrobat Update Service</td><td>Running</td></tr>
      <tr><td>AGMService</td><td>Adobe Genuine Monitor Service</td><td>Running</td></tr>
      <tr><td>AGSService</td><td>Adobe Genuine Software Integrity Service</td><td>Running</td></tr>
      <tr><td>AJRouter</td><td>AllJoyn Router Service</td><td>Stopped</td></tr>
    </table>

  .NOTES
    Author: Lakshmanachari Panuganti
    Date: 3rd July 2025

  .LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
  #>

  [CmdletBinding(DefaultParameterSetName = 'PSObject')]
  Param(
    [Parameter(
      Mandatory,
      ParameterSetName = 'PSObject'
    )]
    [Parameter(ParameterSetName = 'Precontent')]
    [ValidateNotNullOrEmpty()]
    [PSCustomobject] $PSObject,

    [Parameter(ParameterSetName = 'PSObject')]
    [Parameter(ParameterSetName = 'Precontent')]
    [Hashtable] $ConditionalForegroundColor,

    [Parameter(
      Mandatory,
      ParameterSetName = 'Precontent'
    )]
    [String] $PreContent,

    [Parameter(ParameterSetName = 'Precontent')]
    [Validateset('Red', 'Green', 'Orange', 'Yellow', 'Blue')]
    [String] $PreContentColor,

    [Parameter(ParameterSetName = 'Precontent')]
    [Switch] $PreContentBold,

    [Parameter(ParameterSetName = 'Precontent')]
    [Switch] $PreContentItalic,

    [Parameter(Mandatory)]
    [Validateset('List', 'Table')]
    [String] $As
  )

  If ($PreContent) {

    $Report = $PSObject | ConvertTo-Html -Fragment -PreContent "<h2>$PreContent</h2>" -As $As

    If ($PreContentBold.IsPresent) {
      $Report = $Report -replace ('<h2>', '<h2><b>')
      $Report = $Report -replace ('</h2>', '</b></h2>')
    }

    If ($PreContentItalic.IsPresent) {
      $Report = $Report -replace ('<h2>', '<h2><i>')
      $Report = $Report -replace ('</h2>', '</i></h2>')
    }

    If ($PreContentColor) {
      $Report = $Report -replace ('<h2>', "<h2><font color = $PreContentColor>")
      $Report = $Report -replace ('</h2>', '</font></h2>')
    }

  } Else {
    $Report = $PSObject | ConvertTo-Html -Fragment -As $As
  }
  if ($ConditionalForegroundColor) {
    $Keys = $ConditionalForegroundColor.Keys
    $Keys | ForEach-Object {
      $Key = $_
      $Value = $ConditionalForegroundColor[$Key]
      $Report = $Report -replace "<td>$Key</td>", "<td><font color=$Value>$Key</font></td>"
    }
  }
  Return $Report
}
