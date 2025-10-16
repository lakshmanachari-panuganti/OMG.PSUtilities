<#
.SYNOPSIS
    AI Writing Assistant - Grammar correction and email response generation tool powered by Azure OpenAI.

.DESCRIPTION
    This PowerShell function provides a Windows Forms GUI application that leverages Azure OpenAI to:
    - Correct grammar, spelling, and punctuation in text
    - Rephrase content with customizable tone (Professional, Formal, Casual, Friendly)
    - Adjust text length (Same Length, Shorter, More Detailed)
    - Generate professional email responses based on received emails and user context
    
    The tool outputs text formatted in Calibri 10.5pt, optimized for Microsoft Outlook compatibility.
    All output can be copied to clipboard with rich text formatting preserved.

    REQUIREMENTS:
    1. PowerShell 5.1 or higher with Windows Forms support
    2. Active Azure OpenAI Service deployment
    3. The following environment variables must be set before running:
       - API_KEY_AZURE_OPENAI: Your Azure OpenAI API key
       - AZURE_OPENAI_ENDPOINT: Your Azure OpenAI endpoint URL (e.g., https://your-resource.openai.azure.com)
       - AZURE_OPENAI_DEPLOYMENT: Your Azure OpenAI deployment/model name
    
    FEATURES:
    - Dual mode operation: Grammar correction OR Email response generation
    - Customizable tone and length preferences
    - Rich text formatting with Calibri 10.5pt font
    - Copy to clipboard with formatting preserved for Outlook
    - Save output as RTF or plain text files
    - Real-time status updates and error handling

.PARAMETER None
    This function does not accept parameters. All interactions occur through the GUI.

.EXAMPLE
    Start-AIWritingAssistant
    
    Launches the AI Writing Assistant GUI application.

.NOTES
    Author: Lakshmanachari Panuganti
    Date: October 7, 2025
    Version: 1.0
    
    Environment Setup Example:
    $env:API_KEY_AZURE_OPENAI = "your-api-key-here"
    $env:AZURE_OPENAI_ENDPOINT = "https://your-resource.openai.azure.com"
    $env:AZURE_OPENAI_DEPLOYMENT = "gpt-4"

.LINK
    https://learn.microsoft.com/en-us/azure/ai-services/openai/
#>

function Start-AIWritingAssistant {
    [CmdletBinding()]
    param()
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Check environment variables
    if (-not $env:API_KEY_AZURE_OPENAI -or -not $env:AZURE_OPENAI_ENDPOINT -or -not $env:AZURE_OPENAI_DEPLOYMENT) {
        [System.Windows.Forms.MessageBox]::Show(
            "Missing environment variables. Please set:`n`n" +
            "`$env:API_KEY_AZURE_OPENAI`n" +
            "`$env:AZURE_OPENAI_ENDPOINT`n" +
            "`$env:AZURE_OPENAI_DEPLOYMENT",
            "Configuration Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    # Function to copy RichText to clipboard with formatting
    function Copy-RichTextToClipboard {
        param (
            [string]$Text
        )
        
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return
        }
        
        # Create a temporary RichTextBox to generate proper RTF
        $tempRTB = New-Object System.Windows.Forms.RichTextBox
        $tempRTB.Text = $Text
        
        # Apply Calibri 10.5pt to all text
        $tempRTB.SelectAll()
        $calibriFont = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Regular)
        $tempRTB.SelectionFont = $calibriFont
        $tempRTB.Select(0, 0)
        
        # Get the RTF content
        $rtfContent = $tempRTB.Rtf
        
        # Create DataObject for clipboard
        $dataObject = New-Object System.Windows.Forms.DataObject
        
        # Set RTF format
        $dataObject.SetData([System.Windows.Forms.DataFormats]::Rtf, $rtfContent)
        
        # Set plain text
        $dataObject.SetData([System.Windows.Forms.DataFormats]::Text, $Text)
        
        # Create properly formatted HTML for Outlook (CF_HTML format)
        $htmlText = $Text -replace "`r`n", "<br>" -replace "`n", "<br>" -replace "`r", "<br>"
        
        # CF_HTML format requires specific header
        $htmlPrefix = "Version:0.9`r`nStartHTML:00000000`r`nEndHTML:00000000`r`nStartFragment:00000000`r`nEndFragment:00000000`r`n"
        $htmlContent = @"
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
</head>
<body>
<!--StartFragment--><span style="font-family: Calibri; font-size: 14px;">$htmlText</span><!--EndFragment-->
</body>
</html>
"@
        
        $htmlBytes = [System.Text.Encoding]::UTF8.GetBytes($htmlPrefix + $htmlContent)
        $htmlStream = New-Object System.IO.MemoryStream(,$htmlBytes)
        $dataObject.SetData("HTML Format", $htmlStream)
        
        # Set to clipboard with retry
        [System.Windows.Forms.Clipboard]::Clear()
        Start-Sleep -Milliseconds 100
        [System.Windows.Forms.Clipboard]::SetDataObject($dataObject, $true)
        
        # Cleanup
        $tempRTB.Dispose()
        $calibriFont.Dispose()
        $htmlStream.Dispose()
    }

    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AI Writing Assistant - Grammar & Email Response Tool"
    $form.Size = New-Object System.Drawing.Size(1000, 800)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::WhiteSmoke

    $currentY = 10

    # Draft Email Label (initially hidden)
    $labelDraft = New-Object System.Windows.Forms.Label
    $labelDraft.Location = New-Object System.Drawing.Point(10, $currentY)
    $labelDraft.Size = New-Object System.Drawing.Size(300, 20)
    $labelDraft.Text = "Draft Email (Email you received):"
    $labelDraft.Font = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Bold)
    $labelDraft.Visible = $false
    $form.Controls.Add($labelDraft)

    $currentY += 25

    # Draft Email TextBox (initially hidden)
    $textDraft = New-Object System.Windows.Forms.RichTextBox
    $textDraft.Location = New-Object System.Drawing.Point(10, $currentY)
    $textDraft.Size = New-Object System.Drawing.Size(960, 150)
    $textDraft.Font = New-Object System.Drawing.Font("Calibri", 10.5)
    $textDraft.ScrollBars = "Vertical"
    $textDraft.Visible = $false
    $form.Controls.Add($textDraft)

# Store the initial Y position for when draft is hidden
$inputLabelYWhenDraftHidden = 10
$inputTextYWhenDraftHidden = 35
$inputLabelYWhenDraftVisible = $currentY + 160
$inputTextYWhenDraftVisible = $inputLabelYWhenDraftVisible + 25

# Input Label
$labelInput = New-Object System.Windows.Forms.Label
$labelInput.Location = New-Object System.Drawing.Point(10, $inputLabelYWhenDraftHidden)
$labelInput.Size = New-Object System.Drawing.Size(400, 20)
$labelInput.Text = "Your Text (Input):"
$labelInput.Font = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelInput)

# Input TextBox
$textInput = New-Object System.Windows.Forms.RichTextBox
$textInput.Location = New-Object System.Drawing.Point(10, $inputTextYWhenDraftHidden)
$textInput.Size = New-Object System.Drawing.Size(960, 120)
$textInput.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$textInput.ScrollBars = "Vertical"
$form.Controls.Add($textInput)

# Calculate Y position for options panel
$optionsPanelYWhenDraftHidden = $inputTextYWhenDraftHidden + 130
$optionsPanelYWhenDraftVisible = $inputTextYWhenDraftVisible + 130

# Options Panel
$panelOptions = New-Object System.Windows.Forms.Panel
$panelOptions.Location = New-Object System.Drawing.Point(10, $optionsPanelYWhenDraftHidden)
$panelOptions.Size = New-Object System.Drawing.Size(960, 90)
$panelOptions.BorderStyle = "FixedSingle"
$panelOptions.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($panelOptions)

# Follow-up Checkbox
$chkFollowup = New-Object System.Windows.Forms.CheckBox
$chkFollowup.Location = New-Object System.Drawing.Point(10, 10)
$chkFollowup.Size = New-Object System.Drawing.Size(100, 25)
$chkFollowup.Text = "Follow-up"
$chkFollowup.Font = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Bold)
$chkFollowup.ForeColor = [System.Drawing.Color]::DarkBlue
$panelOptions.Controls.Add($chkFollowup)

# Tone Label
$labelTone = New-Object System.Windows.Forms.Label
$labelTone.Location = New-Object System.Drawing.Point(120, 13)
$labelTone.Size = New-Object System.Drawing.Size(80, 20)
$labelTone.Text = "Tone:"
$labelTone.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$panelOptions.Controls.Add($labelTone)

# Tone ComboBox
$comboTone = New-Object System.Windows.Forms.ComboBox
$comboTone.Location = New-Object System.Drawing.Point(200, 10)
$comboTone.Size = New-Object System.Drawing.Size(150, 25)
$comboTone.DropDownStyle = "DropDownList"
$comboTone.Items.AddRange(@("Professional", "Formal", "Casual", "Friendly"))
$comboTone.SelectedIndex = 0
$comboTone.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$panelOptions.Controls.Add($comboTone)

# Length Label
$labelLength = New-Object System.Windows.Forms.Label
$labelLength.Location = New-Object System.Drawing.Point(370, 13)
$labelLength.Size = New-Object System.Drawing.Size(80, 20)
$labelLength.Text = "Length:"
$labelLength.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$panelOptions.Controls.Add($labelLength)

# Length ComboBox
$comboLength = New-Object System.Windows.Forms.ComboBox
$comboLength.Location = New-Object System.Drawing.Point(450, 10)
$comboLength.Size = New-Object System.Drawing.Size(150, 25)
$comboLength.DropDownStyle = "DropDownList"
$comboLength.Items.AddRange(@("Same Length", "Shorter", "More Detailed"))
$comboLength.SelectedIndex = 0
$comboLength.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$panelOptions.Controls.Add($comboLength)

# Generate/Rephrase Button
$btnRephrase = New-Object System.Windows.Forms.Button
$btnRephrase.Location = New-Object System.Drawing.Point(620, 7)
$btnRephrase.Size = New-Object System.Drawing.Size(120, 35)
$btnRephrase.Text = "Rephrase"
$btnRephrase.Font = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Bold)
$btnRephrase.Cursor = [System.Windows.Forms.Cursors]::Hand
$panelOptions.Controls.Add($btnRephrase)

# Clear Button
$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Location = New-Object System.Drawing.Point(750, 7)
$btnClear.Size = New-Object System.Drawing.Size(100, 35)
$btnClear.Text = "Clear All"
$btnClear.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$btnClear.Cursor = [System.Windows.Forms.Cursors]::Hand
$panelOptions.Controls.Add($btnClear)

# Status Label
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Location = New-Object System.Drawing.Point(10, 50)
$labelStatus.Size = New-Object System.Drawing.Size(940, 35)
$labelStatus.Text = "Ready - Uncheck 'Follow-up' for grammar correction, Check 'Follow-up' for email response generation"
$labelStatus.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$labelStatus.ForeColor = [System.Drawing.Color]::Gray
$panelOptions.Controls.Add($labelStatus)

# Calculate Y position for output label
$outputLabelYWhenDraftHidden = $optionsPanelYWhenDraftHidden + 100
$outputLabelYWhenDraftVisible = $optionsPanelYWhenDraftVisible + 100

# Output Label
$labelOutput = New-Object System.Windows.Forms.Label
$labelOutput.Location = New-Object System.Drawing.Point(10, $outputLabelYWhenDraftHidden)
$labelOutput.Size = New-Object System.Drawing.Size(400, 20)
$labelOutput.Text = "Rephrased Text (Output - Calibri 10.5pt):"
$labelOutput.Font = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelOutput)

# Calculate Y position for output text
$outputTextYWhenDraftHidden = $outputLabelYWhenDraftHidden + 25
$outputTextYWhenDraftVisible = $outputLabelYWhenDraftVisible + 25

# Output TextBox
$textOutput = New-Object System.Windows.Forms.RichTextBox
$textOutput.Location = New-Object System.Drawing.Point(10, $outputTextYWhenDraftHidden)
$textOutput.Size = New-Object System.Drawing.Size(960, 200)
$textOutput.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$textOutput.ScrollBars = "Vertical"
$textOutput.ReadOnly = $true
$textOutput.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($textOutput)

# Calculate Y position for button panel
$buttonPanelYWhenDraftHidden = $outputTextYWhenDraftHidden + 210
$buttonPanelYWhenDraftVisible = $outputTextYWhenDraftVisible + 210

# Button Panel
$panelButtons = New-Object System.Windows.Forms.Panel
$panelButtons.Location = New-Object System.Drawing.Point(10, $buttonPanelYWhenDraftHidden)
$panelButtons.Size = New-Object System.Drawing.Size(960, 50)
$form.Controls.Add($panelButtons)

# Copy Button (with formatting)
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Location = New-Object System.Drawing.Point(0, 5)
$btnCopy.Size = New-Object System.Drawing.Size(200, 35)
$btnCopy.Text = "Copy (Calibri 10.5pt)"
$btnCopy.Font = New-Object System.Drawing.Font("Calibri", 10.5, [System.Drawing.FontStyle]::Bold)
$btnCopy.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCopy.Enabled = $false
$panelButtons.Controls.Add($btnCopy)

# Save Button
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(210, 5)
$btnSave.Size = New-Object System.Drawing.Size(120, 35)
$btnSave.Text = "Save to File"
$btnSave.Font = New-Object System.Drawing.Font("Calibri", 10.5)
$btnSave.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSave.Enabled = $false
$panelButtons.Controls.Add($btnSave)

# Follow-up Checkbox Change Event
$chkFollowup.Add_CheckedChanged({
    if ($chkFollowup.Checked) {
        # Show draft email section and adjust layout
        $labelDraft.Visible = $true
        $textDraft.Visible = $true
        
        $labelInput.Location = New-Object System.Drawing.Point(10, $inputLabelYWhenDraftVisible)
        $labelInput.Text = "Your Context/Notes for Response:"
        $textInput.Location = New-Object System.Drawing.Point(10, $inputTextYWhenDraftVisible)
        
        $panelOptions.Location = New-Object System.Drawing.Point(10, $optionsPanelYWhenDraftVisible)
        $labelOutput.Location = New-Object System.Drawing.Point(10, $outputLabelYWhenDraftVisible)
        $labelOutput.Text = "Generated Email Response (Calibri 10.5pt):"
        $textOutput.Location = New-Object System.Drawing.Point(10, $outputTextYWhenDraftVisible)
        $panelButtons.Location = New-Object System.Drawing.Point(10, $buttonPanelYWhenDraftVisible)
        
        $btnRephrase.Text = "Generate"
        $labelStatus.Text = "Follow-up mode: AI will generate email response based on draft and your context"
        
        # Disable length option in follow-up mode
        $comboLength.Enabled = $false
        
    } else {
        # Hide draft email section and restore original layout
        $labelDraft.Visible = $false
        $textDraft.Visible = $false
        
        $labelInput.Location = New-Object System.Drawing.Point(10, $inputLabelYWhenDraftHidden)
        $labelInput.Text = "Your Text (Input):"
        $textInput.Location = New-Object System.Drawing.Point(10, $inputTextYWhenDraftHidden)
        
        $panelOptions.Location = New-Object System.Drawing.Point(10, $optionsPanelYWhenDraftHidden)
        $labelOutput.Location = New-Object System.Drawing.Point(10, $outputLabelYWhenDraftHidden)
        $labelOutput.Text = "Rephrased Text (Output - Calibri 10.5pt):"
        $textOutput.Location = New-Object System.Drawing.Point(10, $outputTextYWhenDraftHidden)
        $panelButtons.Location = New-Object System.Drawing.Point(10, $buttonPanelYWhenDraftHidden)
        
        $btnRephrase.Text = "Rephrase"
        $labelStatus.Text = "Grammar correction mode: AI will fix grammar and rephrase your text"
        
        # Enable length option
        $comboLength.Enabled = $true
    }
})

# Function to call Azure OpenAI API
function Invoke-AzureOpenAI {
    param (
        [string]$InputText,
        [string]$Tone,
        [string]$Length,
        [bool]$IsFollowup,
        [string]$DraftEmail
    )
    
    $endpoint = $env:AZURE_OPENAI_ENDPOINT
    $apiKey = $env:API_KEY_AZURE_OPENAI
    $deployment = $env:AZURE_OPENAI_DEPLOYMENT
    
    if ($IsFollowup) {
        # Follow-up email response mode
        $systemPrompt = @"
You are an expert email assistant. Your task is to:
1. Analyze the received email (draft) and understand its context, tone, and any questions or requests
2. Extract the sender's name if available for personalization
3. Generate a professional email response that:
   - Uses an appropriate greeting (Hi [Name], Dear [Name], etc.)
   - Addresses all points from the received email
   - Incorporates the user's context/notes naturally
   - Uses a $($Tone.ToLower()) tone
   - Automatically determines the appropriate length based on the situation
   - Includes a proper closing (Best regards, Sincerely, etc.)
4. Make the response sound natural, professional, and helpful
5. Don't use "'" for I'm, I’ve, don’t, etc. Use full forms like I am, I have, do not, etc.
6. Should sound like a human wrote it, not AI-generated
Provide ONLY the complete email response without any explanations or meta-commentary.
"@

        $userPrompt = @"
RECEIVED EMAIL:
$DraftEmail

MY CONTEXT/NOTES FOR RESPONSE:
$InputText

Please generate an appropriate email response.
"@
    } else {
        # Grammar correction and rephrasing mode
        $lengthInstruction = switch ($Length) {
            "Shorter" { "Make it concise and shorter while preserving the key message." }
            "More Detailed" { "Expand with more details and clarity where appropriate." }
            default { "Keep approximately the same length." }
        }
        
        $systemPrompt = @"
You are an expert English language assistant. Your task is to:
1. Fix any grammar, spelling, and punctuation errors
2. Rephrase the text to sound natural and fluent    
3. Improve clarity and professionalism where applicable
4. Should sound like a human wrote it, not AI-generated
5. Use a $($Tone.ToLower()) tone
6. $lengthInstruction
7. Don't use "'" for I'm, I’ve, don’t, etc. Use full forms like I am, I have, do not, etc.

Provide ONLY the rephrased text without any explanations, comments, or additional formatting.
"@
        $userPrompt = $InputText
    }

    $uri = "$endpoint/openai/deployments/$deployment/chat/completions?api-version=2024-08-01-preview"
    
    $headers = @{
        "Content-Type" = "application/json"
        "api-key" = $apiKey
    }
    
    $body = @{
        messages = @(
            @{
                role = "system"
                content = $systemPrompt
            },
            @{
                role = "user"
                content = $userPrompt
            }
        )
        temperature = 0.7
        max_tokens = 2000
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
        return $response.choices[0].message.content.Trim()
    }
    catch {
        throw "API Error: $($_.Exception.Message)"
    }
}

# Rephrase/Generate Button Click Event
$btnRephrase.Add_Click({
    # Validation
    if ($chkFollowup.Checked) {
        if ([string]::IsNullOrWhiteSpace($textDraft.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter the draft email (email you received) to generate a response.",
                "Input Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        if ([string]::IsNullOrWhiteSpace($textInput.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter your context/notes for the email response.",
                "Input Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($textInput.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter some text to rephrase.",
                "Input Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
    }
    
    $statusMsg = if ($chkFollowup.Checked) { "Generating email response..." } else { "Processing..." }
    $labelStatus.Text = "$statusMsg Please wait..."
    $labelStatus.ForeColor = [System.Drawing.Color]::Blue
    $btnRephrase.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $textOutput.Text = ""
    $btnCopy.Enabled = $false
    $btnSave.Enabled = $false
    $form.Refresh()
    
    try {
        $result = Invoke-AzureOpenAI -InputText $textInput.Text -Tone $comboTone.SelectedItem -Length $comboLength.SelectedItem -IsFollowup $chkFollowup.Checked -DraftEmail $textDraft.Text
        
        # Set the text with Calibri 10.5pt formatting
        $textOutput.Text = $result
        $textOutput.SelectAll()
        $textOutput.SelectionFont = New-Object System.Drawing.Font("Calibri", 10.5)
        $textOutput.Select(0, 0) # Deselect
        
        $successMsg = if ($chkFollowup.Checked) { "Email response generated successfully!" } else { "Rephrasing completed!" }
        $labelStatus.Text = "$successMsg Copy button will paste with Calibri 10.5pt formatting."
        $labelStatus.ForeColor = [System.Drawing.Color]::Green
        $btnCopy.Enabled = $true
        $btnSave.Enabled = $true
    }
    catch {
        $labelStatus.Text = "Error: $($_.Exception.Message)"
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {
        $btnRephrase.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# Clear Button Click Event
$btnClear.Add_Click({
    $textDraft.Clear()
    $textInput.Clear()
    $textOutput.Clear()
    $comboTone.SelectedIndex = 0
    $comboLength.SelectedIndex = 0
    $chkFollowup.Checked = $false
    $labelStatus.Text = "Ready - Uncheck 'Follow-up' for grammar correction, Check 'Follow-up' for email response generation"
    $labelStatus.ForeColor = [System.Drawing.Color]::Gray
    $btnCopy.Enabled = $false
    $btnSave.Enabled = $false
})

# Copy Button Click Event - With Rich Text Formatting
$btnCopy.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($textOutput.Text)) {
        Copy-RichTextToClipboard -Text $textOutput.Text
        $labelStatus.Text = "Text copied with Calibri 10.5pt formatting! Ready to paste in Outlook/Word."
        $labelStatus.ForeColor = [System.Drawing.Color]::Green
    }
})

# Save Button Click Event
$btnSave.Add_Click({
    if ([string]::IsNullOrWhiteSpace($textOutput.Text)) {
        return
    }
    
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Rich Text Format (*.rtf)|*.rtf|Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $defaultName = if ($chkFollowup.Checked) { "Email_Response" } else { "Rephrased_Text" }
    $saveDialog.FileName = "$($defaultName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').rtf"
    $saveDialog.DefaultExt = "rtf"
    
    if ($saveDialog.ShowDialog() -eq "OK") {
        try {
            if ($saveDialog.FileName -like "*.rtf") {
                # Save as RTF to preserve formatting
                $textOutput.SaveFile($saveDialog.FileName, [System.Windows.Forms.RichTextBoxStreamType]::RichText)
                $labelStatus.Text = "File saved with formatting: $($saveDialog.FileName)"
            }
            else {
                # Save as plain text
                $textOutput.Text | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
                $labelStatus.Text = "File saved as plain text: $($saveDialog.FileName)"
            }
            $labelStatus.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to save file: $($_.Exception.Message)",
                "Save Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
})

    # Show the form
    [void]$form.ShowDialog()
}

# Execute the function
Start-AIWritingAssistant