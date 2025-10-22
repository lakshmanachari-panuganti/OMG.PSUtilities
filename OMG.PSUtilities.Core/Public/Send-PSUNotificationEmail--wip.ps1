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
    $htmlBody = @"
<!DOCTYPE html>
<html>
<body style="margin:0; padding:0; background-color:#f3f3f3; font-family:'Segoe UI', Arial, sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f3f3f3; padding:40px 0;">
    <tr>
      <td align="center">

        <!-- Shadow simulation wrapper -->
        <table width="720" cellpadding="0" cellspacing="0" border="0" style="
          background: linear-gradient(to bottom right, rgba(0,0,0,0.08), rgba(0,0,0,0.03));
          border-radius:16px;
          box-shadow:0 8px 20px rgba(0,0,0,0.25);
          padding:0;
        ">
          <tr>
            <td style="padding:3px;">

              <!-- Main white card -->
              <table width="714" cellpadding="0" cellspacing="0" border="0" style="
                background-color:#ffffff;
                border-radius:16px;
                overflow:hidden;
                box-shadow:0 8px 25px rgba(0,0,0,0.2);
              ">

                <!-- Header -->
                <tr>
                  <td style="background-color:#d9534f; padding:22px 25px; border-top-left-radius:16px; border-top-right-radius:16px;">
                    <h2 style="margin:0; color:#ffffff; font-size:22px; font-weight:600;">Pipeline Failure Alert</h2>
                    <p style="margin:6px 0 0 0; color:#ffffff; font-size:14px;">
                      The <strong>$($HtmlTableContentHash.PipelineName)</strong> pipeline has failed and requires attention
                    </p>
                  </td>
                </tr>

                <!-- Body -->
                <tr>
                  <td style="padding:25px 30px 15px 30px;">
                    <h3 style="margin:0 0 15px 0; font-size:18px; font-weight:700; color:#000000;">
                      Some Content related to the table
                    </h3>

                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse; font-size:14px;">
                      <tr><td width="180" style="background-color:#f8f9fa; padding:8px; font-weight:600;">Pipeline Name</td><td style="padding:8px;">$($HtmlTableContentHash.PipelineName)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Build Number</td><td style="padding:8px;">$($HtmlTableContentHash.BuildNumber)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Build ID</td><td style="padding:8px;">$($HtmlTableContentHash.BuildId)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Branch</td><td style="padding:8px;">$($HtmlTableContentHash.SourceBranch)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Triggered By</td><td style="padding:8px;">$($HtmlTableContentHash.RequestedFor)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Build Result</td><td style="padding:8px; font-weight:700; color:#d9534f;">$($HtmlTableContentHash.BuildResult)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Failed Task</td><td style="padding:8px;">$($HtmlTableContentHash.TaskDisplayName)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Timestamp</td><td style="padding:8px;">$($HtmlTableContentHash.Timestamp)</td></tr>
                      <tr><td style="background-color:#f8f9fa; padding:8px; font-weight:600;">Source Version</td><td style="padding:8px;">$($HtmlTableContentHash.SourceVersion)</td></tr>
                    </table>

                    <!-- CTA Button -->
                    <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin:25px auto 10px auto;">
                      <tr>
                        <td align="center" bgcolor="#007bff" style="border-radius:8px;">
                          <a href="$($EndButton.EndButtonUrl)" target="_blank"
                             style="font-size:14px; color:#ffffff; text-decoration:none; 
                                    padding:12px 24px; display:inline-block; font-weight:500;">
                             $($EndButton.EndButtonText)
                          </a>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color:#f8f9fa; padding:15px 25px; font-size:13px; color:#6c757d; border-top:1px solid #e0e0e0; border-bottom-left-radius:16px; border-bottom-right-radius:16px;">
                    <p style="margin:0;"><strong>Automated Notification</strong> | Azure DevOps Pipeline</p>
                    <p style="margin:4px 0 0 0;">This is an automated message from the Azure SQL Database Inventory pipeline. For questions or support, contact the DevOps team.</p>
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


#Example usage: 
<#
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