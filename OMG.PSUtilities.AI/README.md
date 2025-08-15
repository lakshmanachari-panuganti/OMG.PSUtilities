# OMG.PSUtilities.AI

PowerShell utilities for AI-powered automation and reporting.

> Module version: 1.0.7 | Last updated: 2025-08-11

## 📋 Available Functions

| Function                               | Description                                  |
|-----------------------------------------|----------------------------------------------|
| `Get-PSUAiPoweredGitChangeSummary`      | Summarizes Git changes using AI              |
| `Invoke-PSUGitCommit`                   | Commits changes to Git repository            |
| `Invoke-PSUPromptOnAzureOpenAi`         | Sends prompt to Azure OpenAI                 |
| `Invoke-PSUPromptOnGeminiAi`            | Sends prompt to Gemini AI                    |
| `Invoke-PSUPromptOnPerplexityAi`        | Sends prompt to Perplexity AI                |
| `New-PSUAiPoweredPullRequest`           | Creates a new pull request with AI summary   |
| `Start-PSUGeminiChat`                   | Starts an interactive Gemini AI chat         |

## 📦 Installation

```powershell
Install-Module -Name OMG.PSUtilities.AI -Scope CurrentUser -Repository PSGallery
```

## 📖 Usage Examples

```powershell
# Summarize Git changes using AI
Get-PSUAiPoweredGitChangeSummary -RepositoryPath "C:\MyRepo"

# Commit changes to Git
Invoke-PSUGitCommit -Message "Automated commit via AI"

# Send prompt to Azure OpenAI
Invoke-PSUPromptOnAzureOpenAi -Prompt "Summarize this code..."

# Send prompt to Gemini AI
Invoke-PSUPromptOnGeminiAi -Prompt "Generate a release note for this PR"

# Send prompt to Perplexity AI
Invoke-PSUPromptOnPerplexityAi -Prompt "What is the impact of this change?"

# Create a new AI-powered pull request
New-PSUAiPoweredPullRequest -Repository "MyRepo" -Title "AI Generated PR"

# Start an interactive Gemini AI chat
Start-PSUGeminiChat
```

## 🔗 Links

- [GitHub Repository](https://github.com/lakshmanachari-panuganti)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/OMG.PSUtilities.AI)
- [LinkedIn](https://www.linkedin.com/in/lakshmanachari-panuganti/)

## 📝 Requirements

- PowerShell 5.1 or higher
- Network access to AI services (Azure OpenAI, Gemini, Perplexity, etc.)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.