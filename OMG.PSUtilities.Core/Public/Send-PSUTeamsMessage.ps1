function Send-PSUTeamsMessage {
    <#
    .SYNOPSIS
        Sends a message to a Microsoft Teams channel via webhook.

    .DESCRIPTION
        TODO: Still in testing phrase!
        Posts a simple message to a Teams channel using an incoming webhook URL.
        
        To find or create a Microsoft Teams webhook URL for a channel:
        ==============================================================
        Go to Microsoft Teams and select the team/channel where you want to post messages.
        Click the ... (More options) next to the channel name, then choose Connectors.
        In the Connectors window, search for Incoming Webhook and click Configure.
        Give your webhook a name and (optionally) upload an image.
        Click Create.
        Copy the Webhook URL provided.
        Use this URL as the WebhookUrl parameter in your PowerShell function.

    .PARAMETER WebhookUrl
        The Teams incoming webhook URL.

    .PARAMETER Message
        The message text to send.

    .EXAMPLE
        Send-PSUTeamsMessage -WebhookUrl 'https://outlook.office.com/webhook/...' -Message 'Deployment completed!'

    .NOTES
        Author: Lakshmanachari Panuganti
        File Creation Date: 2025-07-03
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WebhookUrl,
        [Parameter(Mandatory)]
        [string]$Message
    )
    $payload = @{
        text = $Message
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType 'application/json' -Body $payload
        Write-Verbose "Message sent to Teams successfully."
        return $response
    } catch {
        Write-Error "Failed to send message to Teams: $_"
    }
}