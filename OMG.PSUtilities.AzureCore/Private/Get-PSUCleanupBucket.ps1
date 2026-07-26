<#
.SYNOPSIS
    Assigns an Azure App Registration to a cleanup bucket based on its score.

.DESCRIPTION
    Evaluates the Deletion Safety Score, usage status, and Microsoft 1st-party
    flag to assign the app to one of four cleanup buckets:

    Bucket 1 (SafeToDisable)      - Score >= 80, safe to disable now
    Bucket 2 (NeedsInvestigation) - Score 50-79, send to owner for review
    Bucket 3 (LikelyActive)       - Score 20-49, do not touch, gather evidence
    Bucket 4 (BusinessCritical)   - Score < 20 or high-confidence active

    Microsoft 1st-party apps always go to Bucket 4 regardless of score.

.PARAMETER Score
    The Deletion Safety Score (0-100) from Get-PSUDeletionSafetyScore.

.PARAMETER IsUnused
    Whether the app was classified as unused by Get-PSUAppUsageStatus.

.PARAMETER UsageConfidence
    The usage confidence level (High, Medium, Low) from Get-PSUAppUsageStatus.

.PARAMETER IsMicrosoftApp
    Whether this is a Microsoft 1st-party app (detected via AppOwnerOrganizationId).
    Default is $false.

.EXAMPLE
    $bucket = Get-PSUCleanupBucket -Score 85 -IsUnused $true -UsageConfidence "Low"
    $bucket.Bucket  # 1
    $bucket.Label   # "SafeToDisable"
    $bucket.Action  # "DISABLE NOW -> DELETE IN 30 DAYS"

    Assigns a high-score unused app to Bucket 1.

.OUTPUTS
    [Hashtable] with keys: Bucket (int), Label (string), Emoji (string), Action (string).

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>
function Get-PSUCleanupBucket {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$Score,

        [Parameter(Mandatory)]
        [bool]$IsUnused,

        [Parameter(Mandatory)]
        [string]$UsageConfidence,

        [Parameter()]
        [bool]$IsMicrosoftApp = $false
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Score=$Score, IsUnused=$IsUnused, Confidence=$UsageConfidence, MSApp=$IsMicrosoftApp"
    }

    process {
        # OVERRIDE 1: Microsoft 1st-party apps are NEVER cleanup targets
        if ($IsMicrosoftApp) {
            return @{ Bucket = 4; Label = "Microsoft1stParty"; Emoji = [char]0x1F7E2; Action = "DO NOT TOUCH - MICROSOFT OWNED" }
        }

        # OVERRIDE 2: High-confidence active apps
        if (-not $IsUnused -and $UsageConfidence -eq "High") {
            return @{ Bucket = 4; Label = "BusinessCritical"; Emoji = [char]0x1F7E2; Action = "DO NOT TOUCH" }
        }

        switch ($true) {
            ($Score -ge 80) { return @{ Bucket = 1; Label = "SafeToDisable";      Emoji = [char]0x1F534; Action = "DISABLE NOW -> DELETE IN 30 DAYS" } }
            ($Score -ge 50) { return @{ Bucket = 2; Label = "NeedsInvestigation"; Emoji = [char]0x1F7E1; Action = "SEND TO OWNER FOR REVIEW" } }
            ($Score -ge 20) { return @{ Bucket = 3; Label = "LikelyActive";       Emoji = [char]0x1F7E0; Action = "DO NOT TOUCH - GATHER MORE EVIDENCE" } }
            default         { return @{ Bucket = 4; Label = "BusinessCritical";   Emoji = [char]0x1F7E2; Action = "DO NOT TOUCH" } }
        }
    }
}
