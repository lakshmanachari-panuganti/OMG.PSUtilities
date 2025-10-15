# Debug script for Set-PSUADOVariable logic
# Testing variable group variable operations

$Organization = "Lakshmanachari"
$Project = "OMG.PSUtilities"
$PAT = $env:PAT
$VariableGroupId = 1
$VariableName = "TestVariable1"
$VariableValue = "TestValue123"

Write-Host "=== Step 1: Setup ===" -ForegroundColor Cyan
Write-Host "Organization: $Organization"
Write-Host "Project: $Project"
Write-Host "PAT Length: $($PAT.Length)"
Write-Host "Variable Group ID: $VariableGroupId"
Write-Host "Variable Name: $VariableName"
Write-Host "Variable Value: $VariableValue"
Write-Host ""

# Create auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    'Content-Type' = 'application/json'
}

Write-Host "=== Step 2: Get Existing Variable Group ===" -ForegroundColor Cyan
$getUri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/variablegroups/${VariableGroupId}?api-version=7.1-preview.2"
Write-Host "GET URI: $getUri"

try {
    $existingGroup = Invoke-RestMethod -Uri $getUri -Method Get -Headers $headers -ErrorAction Stop
    Write-Host "✓ Successfully retrieved variable group" -ForegroundColor Green
    Write-Host "  Group Name: $($existingGroup.name)"
    Write-Host "  Group Description: $($existingGroup.description)"
    Write-Host "  Existing Variables Count: $($existingGroup.variables.PSObject.Properties.Count)"
    Write-Host "  Existing Variables:"
    foreach ($prop in $existingGroup.variables.PSObject.Properties) {
        $isSecret = if ($prop.Value.isSecret) { " (Secret)" } else { "" }
        Write-Host "    - $($prop.Name): $($prop.Value.value)$isSecret" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Failed to retrieve variable group: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "=== Step 3: Check if Variable Exists ===" -ForegroundColor Cyan
$variableExists = $existingGroup.variables.PSObject.Properties.Name -contains $VariableName
if ($variableExists) {
    Write-Host "✓ Variable '$VariableName' already exists" -ForegroundColor Yellow
    Write-Host "  Current Value: $($existingGroup.variables.$VariableName.value)"
    Write-Host "  Is Secret: $($existingGroup.variables.$VariableName.isSecret)"
} else {
    Write-Host "✓ Variable '$VariableName' does not exist - will be added" -ForegroundColor Green
}
Write-Host ""

Write-Host "=== Step 4: Prepare Update Body ===" -ForegroundColor Cyan
# Clone the existing variables
$updatedVariables = @{}
foreach ($prop in $existingGroup.variables.PSObject.Properties) {
    $updatedVariables[$prop.Name] = @{
        value = $prop.Value.value
    }
    if ($prop.Value.PSObject.Properties.Name -contains 'isSecret') {
        $updatedVariables[$prop.Name].isSecret = $prop.Value.isSecret
    }
}

# Add or update the target variable
if ($variableExists) {
    Write-Host "Updating existing variable '$VariableName'" -ForegroundColor Yellow
    $updatedVariables[$VariableName] = @{
        value = $VariableValue
        isSecret = $existingGroup.variables.$VariableName.isSecret
    }
} else {
    Write-Host "Adding new variable '$VariableName'" -ForegroundColor Green
    $updatedVariables[$VariableName] = @{
        value = $VariableValue
        isSecret = $false
    }
}

# Build the complete update body
$updateBody = @{
    id          = $existingGroup.id
    type        = $existingGroup.type
    name        = $existingGroup.name
    description = $existingGroup.description
    variables   = $updatedVariables
    variableGroupProjectReferences = $existingGroup.variableGroupProjectReferences
}

$jsonBody = $updateBody | ConvertTo-Json -Depth 10 -Compress
Write-Host "Update Body Size: $($jsonBody.Length) bytes"
Write-Host "Variables to be sent:"
foreach ($key in $updatedVariables.Keys) {
    $isSecret = if ($updatedVariables[$key].isSecret) { " (Secret)" } else { "" }
    Write-Host "  - $key : $($updatedVariables[$key].value)$isSecret" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "=== Step 5: Send Update Request ===" -ForegroundColor Cyan
$putUri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/variablegroups/${VariableGroupId}?api-version=7.1-preview.2"
Write-Host "PUT URI: $putUri"

try {
    $response = Invoke-RestMethod -Uri $putUri -Method Put -Headers $headers -Body $jsonBody -ErrorAction Stop
    Write-Host "✓ Successfully updated variable group" -ForegroundColor Green
    Write-Host "  Response Group Name: $($response.name)"
    Write-Host "  Response Variables Count: $($response.variables.PSObject.Properties.Count)"
    Write-Host ""
    
    Write-Host "=== Step 6: Verify Variable in Response ===" -ForegroundColor Cyan
    if ($response.variables.PSObject.Properties.Name -contains $VariableName) {
        Write-Host "✓ Variable '$VariableName' found in response" -ForegroundColor Green
        Write-Host "  Value: $($response.variables.$VariableName.value)"
        Write-Host "  Is Secret: $($response.variables.$VariableName.isSecret)"
    } else {
        Write-Host "✗ Variable '$VariableName' NOT found in response" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "=== Step 7: Verify with Fresh GET ===" -ForegroundColor Cyan
    $verify = Invoke-RestMethod -Uri $getUri -Method Get -Headers $headers -ErrorAction Stop
    if ($verify.variables.PSObject.Properties.Name -contains $VariableName) {
        Write-Host "✓ Variable '$VariableName' confirmed in fresh GET" -ForegroundColor Green
        Write-Host "  Value: $($verify.variables.$VariableName.value)"
        Write-Host "  Is Secret: $($verify.variables.$VariableName.isSecret)"
        
        if ($verify.variables.$VariableName.value -eq $VariableValue) {
            Write-Host "✓ Variable value matches expected value!" -ForegroundColor Green
        } else {
            Write-Host "✗ Variable value mismatch!" -ForegroundColor Red
            Write-Host "  Expected: $VariableValue"
            Write-Host "  Actual: $($verify.variables.$VariableName.value)"
        }
    } else {
        Write-Host "✗ Variable '$VariableName' NOT found in fresh GET" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Failed to update variable group: $_" -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "API Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "=== Debug Script Complete ===" -ForegroundColor Cyan
