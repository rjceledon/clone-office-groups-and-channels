This script copies O365 groups and MSTeams Team Channels from `<USER-EMAIL>` to `<TARGET-EMAIL>`

User should be all set within the Office portal.

Dependencies:

```powershell
Install-Module AzureAD
Install-Module MicrosoftTeams
```

Usage: .\CloneGroups.ps1 `<USER-EMAIL>` `<TARGET-EMAIL>`
