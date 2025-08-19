# OMG.PSUtilities.ActiveDirectory

PowerShell utilities for Active Directory automation and reporting.

> Module version: 1.0.4 | Last updated: 19th August 2025

## 📋 Available Functions

| Function                          | Description                                      |
|------------------------------------|--------------------------------------------------|
| `Find-PSUADServiceAccountMisuse`   | Identifies potential misuse of service accounts by detecting interactive logon events in AD |

## 📦 Installation

```powershell
Install-Module -Name OMG.PSUtilities.ActiveDirectory -Scope CurrentUser -Repository PSGallery
```

## 📖 Usage Example

```powershell
# Find service account misuse in Active Directory
Find-PSUADServiceAccountMisuse -Domain "corp.example.com"
```

## 🔐 Authentication

Some functions may require appropriate domain credentials or elevated permissions.

## 🔗 Links

- [GitHub Repository](https://github.com/lakshmanachari-panuganti)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/OMG.PSUtilities.ActiveDirectory)
- [LinkedIn](https://www.linkedin.com/in/lakshmanachari-panuganti/)

## 📝 Requirements

- PowerShell 5.1 or higher
- Active Directory module (RSAT)
- Appropriate permissions to query AD

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT