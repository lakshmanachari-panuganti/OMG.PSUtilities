# OMG.PSUtilities.AI

PowerShell utilities for AI-powered automation and reporting.

> Module version: 1.0.37 | Last updated: 23rd December 2025

## 📋 Available Functions

| Function                               | Description                                  |
|-----------------------------------------|----------------------------------------------|
| `Get-PSUAiPoweredGitChangeSummary`      | Summarizes file-level changes between two Git branches using AI |
| `Invoke-PSUAiPrompt`                    | Routes prompts to the selected AI provider (Azure OpenAI, Gemini, Perplexity) |
| `Invoke-PSUGitCommit`                   | Generates and commits a conventional Git commit message using AI, then syncs with remote |
| `Invoke-PSUPromptOnAzureOpenAi`         | Sends a prompt to Azure OpenAI (Chat Completions API) and returns the generated response |
| `Invoke-PSUPromptOnGeminiAi`            | Sends a text prompt to the Google Gemini AI model and returns the generated response |
| `Invoke-PSUPromptOnPerplexityAi`        | Sends a text prompt to the Perplexity AI API and returns the generated response |
| `New-PSUAiPoweredPullRequest`           | Uses AI to generate a professional Pull Request title and description from Git changes |
| `Set-PSUAzureOpenAIEnvironment`         | Automates Azure OpenAI Service setup and environment variable configuration |
| `Set-PSUDefaultAiEngine`                | Sets and persists the default AI engine for module use |
| `Start-PSUGeminiChat`                   | Interactive Gemini chatbot using Google's Generative Language API |
| `Update-PSUChangeLog`                   | Uses AI to generate and prepend a changelog entry based on file diffs |

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