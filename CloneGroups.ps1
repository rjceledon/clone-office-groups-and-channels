$UserID = $args[0]
$TargetUserID = $args[1]
Write-Host $UserID $TargetUserID
$ExitMsg = "`n    [!] Exiting...`n"
$Date = Get-Date -Format "MMddyyyyHHmm"
$Log = "CloneGroupsLog" + $Date + ".txt"


#Arg checking
If (($UserID -eq $null) -or ($TargetUserID -eq $null)) {
    Write-Host ("`nThis script copies O365 groups and MSTeams Team Channels from <USER-EMAIL> to <TARGET-EMAIL>`nUser should be all set within the Office portal.`n`n[!] Usage: .\" + $MyInvocation.MyCommand.Name + " <USER-EMAIL> <TARGET-EMAIL>")
    Write-Host -F Red $ExitMsg
    Exit 1
}

#Prompt
Write-Host "[-] Copying information"
$Title = "Copying information"
$Message = "Do you really want to copy all O365 and Team Channels information from " + $UserID + " to " + $TargetUserID + "?`nThis action can't be reverted."
$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Copies all information."
$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Exit."
$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)
$Result = $Host.ui.PromptForChoice($Title, $Message, $Options, 0)
if ($result -eq 1) {
        Write-Host "    [!] You selected No."
        Write-Host -F Red $ExitMsg
        Exit 1
}

### Main
#AzureAD Groups copy
Write-Host "`n[-] Connecting to Azure AD"
Try {
    Connect-AzureAD -Confirm
}
Catch {
    Write-Host -F Red "    [!] Error connecting to AzureAD"
    Write-Host -F Red $ExitMsg
    Exit 1
}

#Get User info
Write-Host "[+] Getting users data"
$User = Get-AzureADUser -ObjectId $UserID
$TargetUser = Get-AzureADUser -ObjectId $TargetUserID

#Get Groups and iterate trying to add groups
Write-Host "[+] Getting groups data"
$Memberships = Get-AzureADUserMembership -ObjectId $User.ObjectId | Where-Object { $_.ObjectType -eq "Group" }
$Memberships | ForEach-Object {
    $CurrentGroup = $_
    If ( -not ($CurrentGroup.Mail -eq $null) ) {
        Try {
            Write-Host "[+] Adding user" $TargetUser.UserPrincipalName "to group" $_.Mail
            Add-AzureADGroupMember -ObjectId $_.ObjectId -RefObjectId $TargetUser.ObjectId
        }
        Catch {
            $ErrorMsg = ($_.Exception.Message -Split '\n')[2] -Replace "Message: "
            $Error = "    [!] Error Adding " + $TargetUserID + " to group " + $CurrentGroup.Mail + ": " + $ErrorMsg
            Write-Host -F Red $Error
            $Date = Get-Date -Format "MM/dd/yyyy HH:mm"
            $Error = $Date + ": " + $Error
            Out-File -Filepath $log -Append -InputObject $Error
        }
    }
}
Write-Host "`n"

#MSTeams Channel copy
Write-Host "`n[-] Connecting to Microsoft Teams"
Try {
    Connect-MicrosoftTeams -Confirm
}
Catch {
    Write-Host -F Red "    [!] Error connecting to Microsoft Teams"
    Write-Host -F Red $ExitMsg
    Exit 1
}



#Get Teams, then Channels and iterate
$Teams = Get-Team -User $UserID
$Teams | ForEach-Object {
    $CurrentGroup = $_
    Write-host "[+] Found team:" $CurrentGroup.DisplayName

    #Add user to Team
    Try {
        Write-Host "[+] Adding user" $TargetUserID "to team" $CurrentGroup.DisplayName
        Add-TeamUser -GroupId $CurrentGroup.GroupId -User $TargetUserID
    }
    Catch {
        $ErrorMsg = ($_.Exception.Message -Split '\n')[2] -Replace "Message: "
        $Error = "    [!] Error Adding " + $TargetUserID + " to team " + $CurrentGroup.DisplayName + ": " + $ErrorMsg
        Write-Host -F Red $Error
        $Date = Get-Date -Format "MM/dd/yyyy HH:mm"
        $Error = $Date + ": " + $Error
        Out-File -Filepath $log -Append -InputObject $Error
    }
    $Channel = Get-TeamChannel -GroupId $CurrentGroup.GroupId
    $Channel | ForEach-Object {
        $CurrentChannel = $_
        $ChannelUsers = Get-TeamChannelUser -GroupId $CurrentGroup.GroupId -DisplayName $CurrentChannel.DisplayName
        If ( ($ChannelUsers.User -Contains $UserID) -and ($ChannelUsers.User -Contains $TargetUserID) ) {
            Write-Host -F Green "    [+]" $UserID "and" $TargetUserID "are both member of" $CurrentChannel.DisplayName
        }
        ElseIf ( ($ChannelUsers.User -Contains $UserID) -and ( -not ($ChannelUsers.User -Contains $TargetUserID) ) ) {
            Write-Host -F Red "    [+]" $UserID "not" $TargetUserID "are both member of" $CurrentChannel.DisplayName

            #Add user to Channel
            Write-Host "[+] Adding user" $TargetUserID "to channel" $CurrentChannel.DisplayName "-" $CurrentGroup.DisplayName
            Try { 
                Add-TeamChannelUser -GroupId $CurrentGroup.GroupId -DisplayName $CurrentChannel.DisplayName -User $TargetUserID
            }
            Catch {
                $ErrorMsg = ($_.Exception.Message -Split '\n')[2] -Replace "Message: "
                $Error = "    [!] Error Adding " + $TargetUserID + " to channel " + $CurrentChannel.DisplayName + ": " + $ErrorMsg
                Write-Host -F Red $Error
                $Date = Get-Date -Format "MM/dd/yyyy HH:mm"
                $Error = $Date + ": " + $Error
                Out-File -Filepath $log -Append -InputObject $ErrorA        
            }
        }
    }
    Write-Host "`n"
}

#Exit
Write-Host "`n[-] Exiting..."
Exit 0
