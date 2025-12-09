function Invoke-OpenAIApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,
        [switch] $ReturnJsonResponse,
        [int] $MaxTokens = 4096,
        [float] $Temperature = 1.0,
        [int] $TimeoutSeconds = 60,
        [int] $RetryCount = 3,
        [int] $RetryDelaySeconds = 2,
        [string] $ApiUrl = "https://omg-openai-proxy-func.azurewebsites.net/api/ProxyOpenAI"
    )

    $body = @{
        Prompt             = $Prompt
        MaxTokens          = $MaxTokens
        Temperature        = $Temperature
        TimeoutSeconds     = $TimeoutSeconds
        ReturnJsonResponse = [bool]$ReturnJsonResponse
    } | ConvertTo-Json -Depth 20

    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            $invokeParams = @{
                Method       = 'Post'
                Uri          = $ApiUrl
                Body         = $body
                Headers      = $headers
                ContentType  = 'application/json'
                TimeoutSec   = $TimeoutSeconds
            }
            $response = Invoke-RestMethod @invokeParams

            Write-Verbose "`nRequest succeeded on attempt $i"

            if ($response -like "*token limit exceeded*") {
                Write-Error $response
                return
            }
            return $response.response
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Warning "Attempt $i failed: $errMsg"

            if ($i -lt $RetryCount) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "All retry attempts failed: $errMsg"
            }
        }
    }
}