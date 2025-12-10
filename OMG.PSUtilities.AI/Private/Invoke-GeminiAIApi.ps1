function Invoke-GeminiAIApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,
        [switch] $ReturnJsonResponse,
        [int] $TimeoutSeconds = 90,
        [int] $RetryCount = 3,
        [int] $RetryDelaySeconds = 2,
        [string] $ApiUrl = "https://omg-geminiai-proxy-func.azurewebsites.net/api/ProxyGeminiAI"
    )

    $body = @{
        Prompt             = $Prompt
        ReturnJsonResponse = [bool]$ReturnJsonResponse
    } | ConvertTo-Json -Depth 20

    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            $invokeParams = @{
                Method      = 'Post'
                Uri         = $ApiUrl
                Body        = $body
                Headers     = $headers
                ContentType = 'application/json'
                TimeoutSec  = $TimeoutSeconds
            }

            $response = Invoke-RestMethod @invokeParams

            Write-Verbose "`n[Gemini] Request succeeded on attempt $i"

            if ($response -is [string] -and $response -like "*token limit exceeded*") {
                Write-Error $response
                return
            }

            return $response.response
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Warning "[Gemini] Attempt $i failed: $errMsg"

            if ($i -lt $RetryCount) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "[Gemini] All retry attempts failed: $errMsg"
            }
        }
    }
}