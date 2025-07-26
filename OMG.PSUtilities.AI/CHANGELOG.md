## Changelog
- Initial scaffolding for OMG.PSUtilities.AI

## [1.0.0] - 2025-07-16
- OMG.PSUtilities.AI.psd1 : Added functions : 'Invoke-PSUPromptAI' and 'Start-PSUAiChat'
- OMG.PSUtilities.AI.psm1 : Added the code to load the private and public functions into the session, and further export public functions.

## [System.Collections.Hashtable] - 2025-07-26
- [Modified File] [Invoke-PSUPromptOnGeminiAi.ps1] : Renamed Invoke-PSUPromptAI to Invoke-PSUPromptOnGeminiAi as I added a new file for Perplexity ai.
- [Modified File] [Invoke-PSUPromptOnPerplexityAi.ps1] : Calls the Perplexity API to generate AI-powered answers with web search and citations.
