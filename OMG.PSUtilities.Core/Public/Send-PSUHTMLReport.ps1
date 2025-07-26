
Function New-PSUHTMLReport {
  <#
  .SYNOPSIS
    Sends HTML reports that are created with New-PSUHTMLReport function.

  .DESCRIPTION
    Sends HTML reports that are created with New-PSUHTMLReport function.
    We can send add Heading, Heading color, Summary, Summary color, Footer, Footer color along with the reports.
    We have to provide the valid html color name or color code.

    Note: SMTP server is hardcoded in the script, you can change it as per your environment.
    The report can be an array of HTML reports that are created with New-PSUHTMLReport function.
    The report can be a string or array of strings that are represented in the email body line by line.
    
  .PARAMETER Heading
    Heading for the email body that appears at the top.

  .PARAMETER HeadingColor
    Valid HTML color name or color code for heading.

  .PARAMETER Summary
    Summary for the email body, It can be an array that is represented in the email report line by line.

  .PARAMETER SummaryColor
    Valid HTML color name or color code for summary.

  .PARAMETER Report
    Report or Array of Reports that needs to send via email.

  .PARAMETER Footer
    Text in the email body that presented all over the down. It can be a string or array.

  .PARAMETER FooterColor
    Valid HTML color name or color code for footer.

  .PARAMETER ReportRecipient
    One or array of email IDs that receives the report.

  .PARAMETER From
    The Email address that the email needs to be sent from.

  .PARAMETER Subject
    The subject of the email.

  .EXAMPLE
    $ReportsHtml = @()

    $ErrorsList = $Error | Select-Object -Property TargetObject, @{N = 'ExceptionMessage'; E={$_.exception.message}}
    $ServicesList = Get-Service | Select-Object Name, DisplayName, Status

    $ConditionalForegroundColor = @{}
    $ConditionalForegroundColor.Add('Running', 'Green')
    $ConditionalForegroundColor.Add('Stopped', 'Red')

    $ErrorParams = @{
      PSObject = $ErrorsList
      PreContent = "List of errors while automation was running"
      PreContentColor = 'Red'
      As = 'Table'
    }
    $ServiceParams = @{
      PSObject = $ServicesList
      ConditionalForegroundColor = $ConditionalForegroundColor
      PreContent = "Services Running on $env:computername"
      PreContentColor = 'Green'
      PreContentBold = $true
      As = 'Table'
    }
    $ReportsHtml += New-PSUHTMLReport @ErrorParams
    $ReportsHtml += New-PSUHTMLReport @ServiceParams


    $Summary = @(
        "Total number of services running: $($ServicesList.count)",
        "Total number of Errors: $($ErrorsList.count)"
    )

    $Footer = @(
        "The automation has been executed on $env:computername",
        "Time elapsed for execution is $Timespan"
    )

    $Params = @{
        Heading = "Services running on $env:computername [$(Get-Date)]"
        Summary = $Summary
        Report = $ReportsHtml
        Footer = $Footer
        From = 'No-Reply@xyz.com'
        Subject = "Services running on $env:computername"
        ReportRecipient = 'lakshmanacharii@xyz.com'
    }
    New-PSUHTMLReport @Params

  .OUTPUTS
  None

  .NOTES
    Author:         Lakshmanachari Panuganti
  #>
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [String] $Subject,

    [Parameter(Mandatory)]
    [String[]] $ReportRecipient, # TODO: validate email address patern

    [Parameter(Mandatory)]
    [String] $From,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Array] $Report,

    [Parameter()]
    [string] $Heading,

    [Parameter()]
    [string] $HeadingColor = '#2B1B17',

    [Parameter()]
    [String[]] $Summary,

    [Parameter()]
    [String] $SummaryColor = '#2B1B17',

    [Parameter()]
    [String[]] $Footer,

    [Parameter()]
    [String] $FooterColor = '#B6B6B4'

  )

  $EmailBody = @()

  #CSS codes
  $CssStyle = @"
<style>

  h1 {
    font-family: calibri;
    color: $HeadingColor;
    font-size: 28px;
  }

  h2 {
    font-family: calibri;
    color: #000000;
    font-size: 16px;
    font-weight:normal;
  }

  p {
    font-family: calibri;
    font-size: 14px;
    color: 	solid black;
  }

  table {
    font-size: 14px;
    border: 0px;
    font-family: calibri;
    border:1px solid black;
  }

  td {
    background: #E0DFDF;
    padding: 4px;
    margin: 0px;
    border: 0;
    border:1px solid black;
  }

  th {
    background: #2B1B17;
    color: #fff;
    font-size: 15px;
    padding: 10px 15px;
    vertical-align: middle;
    border:1px solid black;
  }

  tbody tr:nth-child(even) {
    background: #f0f0f2;
  }

  </style>
  <img src="https://static.vecteezy.com/system/resources/thumbnails/030/776/782/small_2x/logo-computer-science-education-and-software-training-free-png.png" width="35" height="35" /> &nbsp;&nbsp;&nbsp;<br />
"@

  # Formatting the heading, summary, emailbody with required html tags.
  $HeadingHtml = "<h1>$Heading</h1>"
  $SummaryBrAdded = $Summary | ForEach-Object { "$_<br>" }
  $SummaryHtml = "<font color = $SummaryColor><p>$SummaryBrAdded</p></font>"

  $FooterBrAdded = $Footer | ForEach-Object { "$_<br>" }
  $FooterHtml = "<font color = $FooterColor> <p> $FooterBrAdded </p></font>"

  $EmailBody += $CssStyle + $HeadingHtml + $SummaryHtml

  $Report | ForEach-Object {
    $EmailBody += $_
  }
  $EmailBody += $FooterHtml

  $SendEmailParams = @{
    To         = $ReportRecipient
    From       = $From
    Body       = $EmailBody | Out-String
    Subject    = $Subject
    SmtpServer = 'SmtpServer.xyx.com'
    BodyAsHtml = $true
  }
  Send-MailMessage @SendEmailParams
}
