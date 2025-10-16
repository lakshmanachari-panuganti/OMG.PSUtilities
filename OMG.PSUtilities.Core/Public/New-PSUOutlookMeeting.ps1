function New-PSUOutlookMeeting {
    <#
    .SYNOPSIS
        Creates a new meeting in Microsoft Graph/Outlook using Graph PowerShell SDK.

    .DESCRIPTION
        This function creates a new calendar meeting for a specified user with attendees, 
        handling all necessary Microsoft Graph API calls. It supports both regular timed 
        meetings and all-day events.

        An existed Microsoft Graph PowerShell SDK module is required.
        Make sure you have the Microsoft.Graph.Calendar module installed and imported.
        You can install it using: Install-Module Microsoft.Graph.Calendar
        Connect-Mggraph -Scopes "Calendars.ReadWrite", "User.Read.All" is required before running this function.

    .PARAMETER Subject
        The subject/title of the meeting.

    .PARAMETER StartTime
        The start date and time for the meeting. For timed meetings, use format like "2025-10-21 10:00".
        For all-day events, use date format like "2025-10-21".

    .PARAMETER EndTime
        The end date and time for the meeting. For timed meetings, use format like "2025-10-21 10:30".
        For all-day events (single day), use the next day like "2025-10-22".

    .PARAMETER User
        The email address of the user whose calendar will host the meeting.

    .PARAMETER Attendees
        Array of email addresses for meeting attendees.

    .PARAMETER Description
        Optional description/body of the meeting.

    .PARAMETER Location
        Optional location for the meeting.

    .PARAMETER TimeZone
        The time zone for the meeting. Default is "India Standard Time". 
        Not used for all-day events (they use UTC).

    .PARAMETER AttendeeType
        The type of attendees. Valid values: "required", "optional", "resource". Default is "required".

    .PARAMETER IsOnlineMeeting
        If specified, creates the meeting as a Teams online meeting.

    .PARAMETER ShowAs
        How the meeting time should appear on the calendar. Valid values: "free", "tentative", "busy", "oof", "workingElsewhere". Default is "busy".

    .PARAMETER Reminder
        When to send a reminder before the meeting. Valid values: "None", "5 minutes", "15 minutes", "30 minutes", "1 hour", "2 hours", "1 day", "1 week". Default is "15 minutes".

    .PARAMETER IsAllDay
        If specified, creates an all-day event. When this is used, start and end times 
        should be dates only (e.g., "2025-10-21") and will be set to midnight UTC.

    .EXAMPLE
        New-PSUOutlookMeeting -Subject "Team Standup" -StartTime "2025-10-21 10:00" -EndTime "2025-10-21 10:30" -User "user@domain.com" -Attendees @("attendee1@domain.com", "attendee2@domain.com") -Description "Daily standup meeting"

        Creates a basic meeting with required parameters.

    .EXAMPLE
        New-PSUOutlookMeeting -Subject "Holiday" -StartTime "2025-12-25" -EndTime "2025-12-26" -User "user@domain.com" -IsAllDay -Description "Christmas Day"

        Creates an all-day event for Christmas Day.

    .EXAMPLE
        $description = "<div style='font-family: Calibri; font-size: 10.5pt;'>Test-Meeting scheduled by <span style='background-color: #FFFF00;'>PowerShell</span></div>"
        $subject = "Test-Meeting scheduled by PowerShell"
        $meetingParams = @{
            Subject      = $subject
            StartTime    = "2025-10-20"
            EndTime      = "2025-10-21"
            User         = $env:MY_EMAIL
            Attendees    = $env:MEETING_ATTENDEES.Split(",")
            Description  = $description
            ShowAs       = "free"
            Reminder     = "None"
            IsAllDay     = $true
        }
        New-PSUOutlookMeeting @meetingParams

    .NOTES
        Requires Microsoft.Graph.Calendar module and appropriate permissions.
        For all-day events, times are automatically set to midnight UTC as required by Microsoft Graph.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$StartTime,

        [Parameter(Mandatory = $true)]
        [string]$EndTime,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $false)]
        [string[]]$Attendees = @(),

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $false)]
        [string]$Location = "",

        [Parameter(Mandatory = $false)]
        [string]$TimeZone = "India Standard Time",

        [Parameter(Mandatory = $false)]
        [ValidateSet("required", "optional", "resource")]
        [string]$AttendeeType = "required",

        [Parameter(Mandatory = $false)]
        [switch]$IsOnlineMeeting,

        [Parameter(Mandatory = $false)]
        [ValidateSet("free", "tentative", "busy", "oof", "workingElsewhere")]
        [string]$ShowAs = "busy",

        [Parameter(Mandatory = $false)]
        [ValidateSet("None", "5 minutes", "15 minutes", "30 minutes", "1 hour", "2 hours", "1 day", "1 week")]
        [string]$Reminder = "15 minutes",

        [Parameter(Mandatory = $false)]
        [switch]$IsAllDay
    )

    begin {
        Write-Verbose "Starting New-PSUOutlookMeeting function"
        Write-Verbose "Subject: $Subject"
        Write-Verbose "User: $User"
        Write-Verbose "IsAllDay: $IsAllDay"
        Write-Verbose "StartTime: $StartTime"
        Write-Verbose "EndTime: $EndTime"

        # Check if Microsoft.Graph.Calendar module is available
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Calendar)) {
            throw "Microsoft.Graph.Calendar module is not installed. Please install it using: Install-Module Microsoft.Graph.Calendar"
        }

        # Import the module if not already loaded
        if (-not (Get-Module -Name Microsoft.Graph.Calendar)) {
            Import-Module Microsoft.Graph.Calendar
        }
    }

    process {
        try {
            # Convert reminder string to minutes
            $reminderMinutes = switch ($Reminder) {
                "None" { 0 }
                "5 minutes" { 5 }
                "15 minutes" { 15 }
                "30 minutes" { 30 }
                "1 hour" { 60 }
                "2 hours" { 120 }
                "1 day" { 1440 }
                "1 week" { 10080 }
                default { 15 }
            }

            # Build attendees array
            $attendeeList = @()
            foreach ($attendeeEmail in $Attendees) {
                $attendeeList += @{
                    emailAddress = @{
                        address = $attendeeEmail
                        name = $attendeeEmail
                    }
                    type = $AttendeeType
                }
            }

            # Build the meeting body based on whether it's all-day or not
            if ($IsAllDay) {
                Write-Verbose "Creating all-day event with midnight UTC times"
                # For all-day events, Microsoft Graph requires midnight times in the same timezone
                $EventBody = @{
                    subject = $Subject
                    start = @{
                        dateTime = "${StartTime}T00:00:00.0000000"
                        timeZone = "UTC"
                    }
                    end = @{
                        dateTime = "${EndTime}T00:00:00.0000000"
                        timeZone = "UTC"
                    }
                    isAllDay = $true
                    showAs = $ShowAs
                }
            } else {
                Write-Verbose "Creating regular timed event"
                $EventBody = @{
                    subject = $Subject
                    start = @{
                        dateTime = $StartTime
                        timeZone = $TimeZone
                    }
                    end = @{
                        dateTime = $EndTime
                        timeZone = $TimeZone
                    }
                    isAllDay = $false
                    showAs = $ShowAs
                }
            }

            # Add optional fields if provided
            if ($Description) {
                # Check if description contains HTML tags
                if ($Description -match '<[^>]+>') {
                    $EventBody.body = @{
                        contentType = "HTML"
                        content = $Description
                    }
                } else {
                    $EventBody.body = @{
                        contentType = "text"
                        content = $Description
                    }
                }
            }

            if ($Location) {
                $EventBody.location = @{
                    displayName = $Location
                }
            }

            if ($attendeeList.Count -gt 0) {
                $EventBody.attendees = $attendeeList
            }

            if ($reminderMinutes -gt 0) {
                $EventBody.isReminderOn = $true
                $EventBody.reminderMinutesBeforeStart = $reminderMinutes
            } else {
                $EventBody.isReminderOn = $false
            }

            if ($IsOnlineMeeting) {
                $EventBody.isOnlineMeeting = $true
                $EventBody.onlineMeetingProvider = "teamsForBusiness"
            }

            # Convert to JSON for debugging
            $jsonBody = $EventBody | ConvertTo-Json -Depth 10
            Write-Verbose "Event body JSON:"
            Write-Verbose $jsonBody

            # Create the meeting
            Write-Verbose "Creating meeting via Microsoft Graph API..."
            $result = New-MgUserEvent -UserId $User -BodyParameter $EventBody

            if ($result) {
                Write-Host "Meeting created successfully!" -ForegroundColor Green
                Write-Host "Meeting ID: $($result.Id)" -ForegroundColor Cyan
                Write-Host "Subject: $($result.Subject)" -ForegroundColor Cyan
                Write-Host "Start: $($result.Start.DateTime) ($($result.Start.TimeZone))" -ForegroundColor Cyan
                Write-Host "End: $($result.End.DateTime) ($($result.End.TimeZone))" -ForegroundColor Cyan
                Write-Host "Is All Day: $($result.IsAllDay)" -ForegroundColor Cyan
                
                if ($result.WebLink) {
                    Write-Host "Web Link: $($result.WebLink)" -ForegroundColor Yellow
                }

                return $result
            } else {
                Write-Error "Failed to create meeting - no result returned"
            }

        } catch {
            Write-Error "Error creating meeting: $($_.Exception.Message)"
            Write-Error "Full error details: $_"
            
            # If there's a specific HTTP response, show it
            if ($_.Exception.Response) {
                Write-Error "HTTP Status: $($_.Exception.Response.StatusCode)"
            }           
            throw
        }
    }
}