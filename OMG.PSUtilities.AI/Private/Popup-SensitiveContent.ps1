function Popup-SensitiveContent {
    function Popup-SensitiveContent {
    <#
    .SYNOPSIS
    Displays a security warning popup when potential hardcoded sensitive data is detected in files.

    .DESCRIPTION
    This function scans the provided files for potentially hardcoded sensitive information such as passwords, secrets,
    API keys, tokens, and connection strings. If any sensitive content is detected, a modern GUI popup is displayed
    showing the affected files, line numbers, and masked values.

    The popup allows the user to either:
    - Continue with the operation (acknowledging the risk), or
    - Cancel the operation to prevent accidental exposure.

    The function intelligently ignores:
    - Common binary and build artifact file types
    - Azure DevOps variable references like $(VariableName)
    - Azure resource scope identifiers (subscriptions, resourceGroups, etc.)
    - Files listed via extension ignore rules

    Additional custom regex patterns can be externally configured using:
        %APPDATA%\Popup-SensitiveContent.config

    Key Features:
    - Modern WPF popup UI
    - Masked display of detected secrets
    - Configurable external pattern support
    - Safe handling of DevOps variable references
    - Moderate detection to reduce false positives

    Recommended Usage:
    Integrate this function before Git commits, pull request creation, or pipeline execution to prevent
    accidental leakage of credentials or sensitive configuration.

    .PARAMETER Files
    An array of file paths to be scanned for sensitive content.

    .EXAMPLE
    $files = @(
        "C:\Scripts\Deploy.ps1",
        "C:\Configs\appsettings.json"
    )
    Popup-SensitiveContent -Files $files

    Displays a warning popup if sensitive values are detected and returns the user's decision.

    .EXAMPLE
    if (-not (Popup-SensitiveContent -Files $changedFiles)) {
        throw "Operation aborted due to detected sensitive content."
    }

    Integrates with commit pipelines or automation scripts to block unsafe operations when sensitive data is found.

    .OUTPUTS
    System.Boolean

    Returns:
    - $true  -> User chose to Continue
    - $false -> User chose to Cancel

    .NOTES
    Author : Lakshmanachari Panuganti
    Date: 20 th November 2025

    #>

    param(
        [array]$Files
    )

    $IgnoreExtensions = @(
        '.exe', '.dll', '.pdb', '.obj', '.class', '.o', '.so', '.a', '.lib', '.dylib', '.bin',
        '.tmp', '.temp', '.bak', '.old', '.swp', '.orig',
        '.lock',
        '.log'
    )

    # Filter files before scanning
    $Files = $Files | Where-Object {
        $_ -and (Test-Path $_) -and
        (-not ($IgnoreExtensions -contains ([IO.Path]::GetExtension($_).ToLower())))
    }

    if ($Files.Count -eq 0) { return $true }

    # Sensitive data patterns
    $Patterns = @(
        '(?i)["'']?\s*(password|passwd|pwd)\s*["'']?\s*[:=]\s*["'']?[^"'']+["'']?',
        '(?i)["'']?\s*(secret|clientsecret)\s*["'']?\s*[:=]\s*["'']?[^"'']+["'']?',
        '(?i)["'']?\s*(apikey|api[_-]?key)\s*["'']?\s*[:=]\s*["'']?[^"'']+["'']?',
        '(?i)["'']?\s*(token|accesstoken|authtoken)\s*["'']?\s*[:=]\s*["'']?[^"'']+["'']?',
        '(?i)["'']?\s*(connectionstring|connstring|db[_-]?conn)\s*["'']?\s*[:=]\s*["'']?[^"'']+["'']?',
        'AKIA[0-9A-Z]{16}',
        'ghp_[A-Za-z0-9]{36}',
        'github_pat_[A-Za-z0-9]{22,64}',
        'AIza[0-9A-Za-z\-_]{35}'
    )

    # External file that users can add customize patterns at anytime!
    $configPath = "$env:APPDATA\Popup-SensitiveContent.config"

    if (Test-Path $configPath) {
        $externalPatterns = Get-Content -Path $configPath -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }

        $Patterns += $externalPatterns
    }

    $findings = @()

    foreach ($file in $Files) {
        $content = Get-Content $file -ErrorAction SilentlyContinue

        for ($i = 0; $i -lt $content.Count; $i++) {
            $line = $content[$i]

            if ($line -match '(?i)(subscriptions\/|resourceGroups\/|managementGroups\/|providers\/Microsoft)') { continue }

            foreach ($pattern in $Patterns) {
                if ($line -match $pattern) {

                    $raw = $Matches[0]

                    # Ignore Azure DevOps variable references like $(VAR)
                    if ($raw -match '\$\([^)]+\)') { continue }

                    if ($raw -match '[:=]\s*["''](.+?)["'']') {
                        $secret = $Matches[1]
                        if ($secret.Length -gt 2) {
                            $mask = $secret.Substring(0, 2) + ('*' * ($secret.Length - 2))
                        } else {
                            $mask = '*' * $secret.Length
                        }
                        $masked = $raw -replace [regex]::Escape($secret), $mask
                    } else {
                        $masked = $raw
                    }

                    $findings += [pscustomobject]@{
                        File  = $file
                        Line  = $i + 1
                        Match = $masked
                    }
                }
            }
        }
    }

    if ($findings.Count -eq 0) { return $true }

    # Build and show popup
    $groups = $findings | Sort-Object File, Line | Group-Object File

    foreach ($g in $groups) {
        $text += "FILE: $($g.Name)`r`n"
        foreach ($item in $g.Group) {
            $text += "  • Line $($item.Line): $($item.Match)`r`n"
        }
        $text += "`r`n"
    }

    Add-Type -AssemblyName PresentationFramework

    $XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Security Alert"
        Height="650" Width="950"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        Background="#F3F4F6">

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Background="#C62828" Padding="16" CornerRadius="8">
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="⚠" FontSize="22" Foreground="White" Margin="0,0,8,0"/>
                <TextBlock Text="SENSITIVE DATA DETECTED"
                           Foreground="White"
                           FontWeight="SemiBold"
                           FontSize="20"/>
            </StackPanel>
        </Border>

        <Border Grid.Row="1" Margin="0,16,0,16" Padding="14"
                Background="White" CornerRadius="8"
                BorderBrush="#E5E7EB" BorderThickness="1">

            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <TextBox Name="Content"
                         TextWrapping="Wrap"
                         BorderThickness="0"
                         FontFamily="Calibri"
                         FontSize="14"
                         IsReadOnly="True"
                         Background="White"/>
            </ScrollViewer>
        </Border>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="ContinueBtn" Content="Continue" Width="140" Height="40" Margin="6"/>
            <Button Name="CancelBtn" Content="Cancel" Width="140" Height="40" Margin="6"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $window.FindName("Content").Text = $text

    $window.FindName("ContinueBtn").Add_Click({
            $window.Tag = $true
            $window.Close()
        })

    $window.FindName("CancelBtn").Add_Click({
            $window.Tag = $false
            $window.Close()
        })

    $window.Topmost = $true
    $window.ShowInTaskbar = $true

    $window.ShowDialog() | Out-Null
    return $window.Tag
}
