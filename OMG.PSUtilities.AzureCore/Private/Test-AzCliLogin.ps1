function Test-AzCliLogin {
    <#
    .SYNOPSIS
    Ensures Azure CLI is logged in and has a valid token.

    .DESCRIPTION
    This function checks if Azure CLI is logged in and has a valid session. 
    If not logged in, it prompts for login. If already logged in, it refreshes the access token.

    .NOTES
    Author: Lakshmanachari Panuganti
    Date  : 2025-08-11
    #>
    
    try {
        # Check if already logged in
        $accountCheck = az account show 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Azure CLI login required. Logging in..." -ForegroundColor Yellow
            
            try {
                az login --scope https://management.core.windows.net//.default | Out-Null
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Azure CLI login failed with exit code: $LASTEXITCODE"
                }
                
                Write-Host "Azure CLI login successful." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to login to Azure CLI: $($_.Exception.Message)"
                throw
            }
        }
        else {
            Write-Verbose "Azure CLI session is active. Refreshing access token..."
            
            try {
                az account get-access-token --resource=https://management.azure.com/ | Out-Null
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to refresh Azure CLI access token with exit code: $LASTEXITCODE"
                }
                
                Write-Verbose "Azure CLI access token refreshed successfully."
            }
            catch {
                Write-Warning "Failed to refresh access token: $($_.Exception.Message). Attempting re-login..."
                
                # If token refresh fails, try to login again
                try {
                    az login --scope https://management.core.windows.net//.default | Out-Null
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "Azure CLI re-login failed with exit code: $LASTEXITCODE"
                    }
                    
                    Write-Host "Azure CLI re-login successful." -ForegroundColor Green
                }
                catch {
                    Write-Error "Failed to re-login to Azure CLI: $($_.Exception.Message)"
                    throw
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}