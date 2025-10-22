function Send-PSUNotificationEmail {
    param (
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [string]$Caption,
        [Parameter(Mandatory)] [string]$ErrorDetailHtml,
        [Parameter(Mandatory)] [hashtable]$HtmlTableContentHash,
        [Parameter(Mandatory)] [hashtable]$EndButton,
        [Parameter(Mandatory)] [string]$SmtpServerName,
        [Parameter(Mandatory)] [int]$SmtpPort, 
        [Parameter(Mandatory)] [string]$From,
        [Parameter(Mandatory)] [string[]]$To,
        [Parameter(Mandatory)] [string]$Subject,
        [Parameter()] [string]$Priority,
        [Parameter()] [bool]$EnableSsl = $false
    )

    # Validate required parameters
    if (-not $SmtpServerName -or -not $SmtpPort -or -not $From -or -not $To) {
        Write-Host "Missing required SMTP parameters!" -ForegroundColor Red
        return
    }

    if ($To.Count -eq 0) {
        Write-Host "No recipients specified. Please provide email addresses in the 'To' field." -ForegroundColor Red
        return
    }

    # Ensure priority is mapped to MailPriority enum
    $Priority = if ($Priority) { 
        if ([Enum]::IsDefined([System.Net.Mail.MailPriority], $Priority)) {
            [System.Net.Mail.MailPriority]::$Priority
        } else {
            Write-Host "Invalid priority specified, defaulting to 'Normal'" -ForegroundColor Yellow
            [System.Net.Mail.MailPriority]::Normal
        }
    } else {
        [System.Net.Mail.MailPriority]::Normal
    }

    # Build table rows dynamically
    $tableRows = ""
    foreach ($key in $HtmlTableContentHash.Keys) {
        $escapedValue = [System.Web.HttpUtility]::HtmlEncode($HtmlTableContentHash[$key])
        if ($key -eq 'BuildResult') {
            $tableRows += "<tr><th>$key</th><td class='status-failed'>$escapedValue</td></tr>`n"
        } else {
            $tableRows += "<tr><th>$key</th><td>$escapedValue</td></tr>`n"
        }
    }

    # Compose HTML body
    # Compose HTML body
$htmlBody = @"
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <!--[if mso]>
  <style type="text/css">
    body, table, td {font-family: Arial, sans-serif !important;}
  </style>
  <![endif]-->
</head>
<body style="margin:0; padding:0; background-color:#f3f3f3; font-family:Arial, sans-serif;">

  <!-- Outer wrapper table -->
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f3f3f3;">
    <tr>
      <td align="center" style="padding:40px 20px;">

        <!-- Main container - 600px width (Outlook safe) -->
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff; border:1px solid #d0d0d0;">
          
          <!-- Red header bar -->
          <tr>
            <td style="background-color:#d9534f; padding:0;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding:24px 28px;">
                    <h2 style="margin:0; padding:0; color:#ffffff; font-size:24px; font-weight:bold; line-height:1.3;">
                      ⚠️ Pipeline Failure Alert
                    </h2>
                    <p style="margin:8px 0 0 0; padding:0; color:#ffffff; font-size:15px; line-height:1.4;">
                      The <strong>$($HtmlTableContentHash.PipelineName)</strong> pipeline has failed and requires immediate attention.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main content area -->
          <tr>
            <td style="padding:28px 28px 20px 28px;">
              
              <!-- Section heading -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding:0 0 16px 0;">
                    <h3 style="margin:0; padding:0; font-size:18px; font-weight:bold; color:#333333; line-height:1.3;">
                      Pipeline Details
                    </h3>
                  </td>
                </tr>
              </table>

              <!-- Details table -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse; border:1px solid #e0e0e0;">
                
                <!-- Pipeline Name -->
                <tr>
                  <td width="180" style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Pipeline Name
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.PipelineName)
                  </td>
                </tr>

                <!-- Build Number -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Build Number
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.BuildNumber)
                  </td>
                </tr>

                <!-- Build ID -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Build ID
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.BuildId)
                  </td>
                </tr>

                <!-- Branch -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Branch
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.SourceBranch)
                  </td>
                </tr>

                <!-- Triggered By -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Triggered By
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.RequestedFor)
                  </td>
                </tr>

                <!-- Build Result (highlighted) -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Build Result
                  </td>
                  <td style="background-color:#ffe5e5; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#d9534f; vertical-align:top;">
                    ❌ $($HtmlTableContentHash.BuildResult)
                  </td>
                </tr>

                <!-- Failed Task -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Failed Task
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.TaskDisplayName)
                  </td>
                </tr>

                <!-- Timestamp -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; border-bottom:1px solid #e0e0e0; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Timestamp
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-bottom:1px solid #e0e0e0; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.Timestamp)
                  </td>
                </tr>

                <!-- Source Version -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:10px 12px; font-size:14px; font-weight:bold; color:#333333; vertical-align:top;">
                    Source Version
                  </td>
                  <td style="background-color:#ffffff; padding:10px 12px; border-left:1px solid #e0e0e0; font-size:14px; color:#333333; vertical-align:top;">
                    $($HtmlTableContentHash.SourceVersion)
                  </td>
                </tr>

              </table>

              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" style="padding:28px 0 10px 0;">
                    <table cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="center" bgcolor="#007bff" style="padding:14px 32px;">
                          <a href="$($EndButton.EndButtonUrl)" target="_blank" style="font-size:15px; font-weight:bold; color:#ffffff; text-decoration:none; display:block;">
                            $($EndButton.EndButtonText)
                          </a>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#f8f9fa; padding:20px 28px; border-top:2px solid #e0e0e0;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="font-size:13px; color:#6c757d; line-height:1.5;">
                    <p style="margin:0 0 6px 0; padding:0; font-weight:bold; color:#495057;">
                      Automated Notification | Azure DevOps Pipeline
                    </p>
                    <p style="margin:0; padding:0;">
                      This is an automated message from the Azure SQL Database Inventory pipeline. For questions or support, contact the DevOps team.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>
"@


    # Create and send the email
    $mail = New-Object System.Net.Mail.MailMessage
    $mail.From = $From
    $To | ForEach-Object { $mail.To.Add($_) }
    $mail.Subject = $Subject
    $mail.Body = $htmlBody
    $mail.IsBodyHtml = $true
    $mail.Priority = $Priority

    $smtp = New-Object System.Net.Mail.SmtpClient($SmtpServerName, $SmtpPort) 
    $smtp.EnableSsl = $EnableSsl
    $smtp.UseDefaultCredentials = $true

    try {
        $smtp.Send($mail)
        Write-Host "SMTP Send() completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "SMTP Send() failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "   Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
    }

    $mail.Dispose()
    $smtp.Dispose()
}


<#Example usage: 

$Title = "Pipeline Failure Details"
$Caption  = "The SO N SO pipeline has failed and requires attention"
$ErrorDetailHtml = "<html><body><h1>Some Content related to the table </h1></body></html>"

$HtmlTableContentHash = @{
    PipelineName      = 'so and so pipeline'
    BuildNumber       = 12312
    BuildId           = 999
    SourceBranch      = 'dev'
    RequestedFor      = 'lucky'
    BuildResult       = 'Failed'
    TaskDisplayName   = 'Build Task'
    Timestamp         = '2023-10-01T12:00:00Z'
    SourceVersion     = 'abcdef123456'
}

$EndButton = @{
    EndButtonText = "Help Resolve Issue"
    EndButtonUrl  = 'www.google.com'
}

$SmtpServerName = $env:SMTP_SERVER
$SmtpPort = 25
$From = $env:FROM
$To = @($env:TO)
$Subject = "Pipeline Failed: $($HtmlTableContentHash.PipelineName) | Build #$($HtmlTableContentHash.BuildNumber)"
$Priority = "High"

Send-PSUNotificationEmail -Title $Title -Caption $Caption -ErrorDetailHtml $ErrorDetailHtml -HtmlTableContentHash $HtmlTableContentHash -EndButton $EndButton -SmtpServerName $SmtpServerName -SmtpPort $SmtpPort -From $From -To $To -Subject $Subject -Priority $Priority
#>