# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT 
# SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE
#
$version="0.0.0.2"
$RunAsAutomation = $false

if ($RunAsAutomation)
{
$partnerId = Get-AutomationVariable -Name 'GroupSync-partnerId'
$groupSearchString = Get-AutomationVariable -Name 'GroupSync-groupSearchString'
$InviteRedirectUrl = Get-AutomationVariable -Name 'GroupSync-InviteRedirectUrl'
$groupDescription = Get-AutomationVariable -Name 'GroupSync-groupDescription'
$cred = Get-AutomationPSCredential -Name 'GroupSync-SyncAccount'
}
else
{
$partnerId = "xxxxxxxxx-c1e1-42d0-xxxxxxxxxxxxxx"
$groupSearchString = "_theprefix-"
$InviteRedirectUrl = "http://www.microsoft.com"
$groupDescription = "Automated group creation - Do not remove or do not change"
$User = "xxxxx@xxxxxx.xxx"
$PWord = ConvertTo-SecureString -String "xxxxxxxxxxxx" -AsPlainText -Force
$cred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord
}

if (($partnerId -eq $null) -or ($groupSearchString -eq $null)  -or ($InviteRedirectUrl -eq $null) -or ($groupDescription -eq $null) -or ($cred -eq $null)) {
    Write-Host "Variables validation failed"
    exit 2
}

Write-Host "Script version" $version
Connect-AzureAD -TenantId $partnerId -Credential $cred
$whiteListMembers = New-Object System.Collections.ArrayList
$whiteListMembers.Add($cred.UserName) | out-null

# Get all groups
$groups = Get-AzureADGroup -SearchString $groupSearchString -All $true 

# Get all group members for each group
$groupMembers = New-Object System.Collections.ArrayList
ForEach ($group in $groups) { 
    $members = Get-AzureADGroupMember -ObjectId $group.Objectid
    ForEach ($member in $members) { 
    $tempMember = New-Object System.Object
    $tempMember | Add-Member -MemberType NoteProperty -Name "groupObjectId" -Value $group.Objectid
    $tempMember | Add-Member -MemberType NoteProperty -Name "groupMailNickName" -Value $group.MailNickName
    $tempMember | Add-Member -MemberType NoteProperty -Name "userObjectId" -Value $member.ObjectID
    $tempMember | Add-Member -MemberType NoteProperty -Name "userPrincipalName" -Value $member.userPrincipalName
    $tempMember | Add-Member -MemberType NoteProperty -Name "displayName" -Value $member.displayName
    $groupMembers.Add($tempMember) | out-null}
}

# Get all contracts
$contracts = Get-AzureADContract -All $true

#functions
function DoesUserExistInPartnerAD ([string] $userPrincipalName){
ForEach ($groupMember in $groupMembers){
    if ($userPrincipalName.Contains((($groupMember.userPrincipalName -replace '@', '_')+"#EXT#" ))) { return $true }
}
return $false

} 

function DoesUserExistInTenantAD ([string] $userPrincipalName){
ForEach ($tenantUser in $tenantUsers){
    if ($tenantUser.userPrincipalName.Contains((($userPrincipalName -replace '@', '_') + "#EXT#"))) { return $true}
}
return $false

} 

function DoesUserExistInWhiteList ([string] $userPrincipalName){
ForEach ($whiteListMember in $whiteListMembers){
    if ($userPrincipalName.Contains($whiteListMember.Replace('@', '_')+"#EXT#")) { return $true }
    if (($whiteListMember.Replace('@', '_')+"#EXT#").Contains($userPrincipalName)) { return $true }
    if ($userPrincipalName.Contains($whiteListMember)) { return $true }
    if ($whiteListMember.Contains($userPrincipalName)) { return $true }
}
return $false
}

function IsLocalUser ([string] $userPrincipalName){
if ($userPrincipalName -contains "#EXT#") { return $false }
return $true
} 

function DoesTenantGroupExist([string] $mailNickName){
ForEach ($group in $groups) { 
    if($group.MailNickName.ToLower().Equals($mailNickName.ToLower())) {return $true}
}

return $false
}

function DoesPartnerGroupExist([string] $mailNickName){
ForEach ($tenantGroup in $tenantGroups) { 
    if($tenantGroup.MailNickName.ToLower().Equals($mailNickName.ToLower())) {return $true}
}

return $false
}

function DoesTenantGroupMemberExist([string] $mailNickName, [string] $userPrincipalName)
{
ForEach ($groupMember in $groupMembers){
    if (($userPrincipalName.Contains((($groupMember.userPrincipalName -replace '@', '_')+"#EXT#" ))) -and
        ($mailNickName.ToLower().Equals($groupMember.groupMailNickName.ToLower())))
     { return $true }
}

return $false
}

function DoesPartnerGroupMemberExist( $groupMember)
{

ForEach ($lookupTenantGroupMember in $lookupTenantGroupMembers){
    if (($lookupTenantGroupMember.userPrincipalName.Contains((($groupMember.userPrincipalName -replace '@', '_')+"#EXT#" ))) -and
        ($groupMember.groupMailNickName.ToLower().Equals($lookupTenantGroupMember.groupMailNickName.ToLower())))
     { return $true }
}
return $false
}

function GetTenantGroupObjectId([string] $mailNickName)
{
ForEach ($tenantGroup in $tenantGroups){
    if ($mailNickName.ToLower().Equals($tenantGroup.mailNickName.ToLower()))
     { return $tenantGroup.ObjectId }
}
return $null
}

function GetTenantUserObjectId([string] $userPrincipalName)
{
ForEach ($tenantUser in $tenantUsers){
    if ($tenantUser.userPrincipalName.Contains((($userPrincipalName -replace '@', '_')+"#EXT#" )))
     { return $tenantUser.ObjectId }
}
return $null
}


ForEach($contract in $contracts){

Connect-AzureAD -TenantId $contract.CustomerContextId -Credential $cred

# Begin Sync external users ==========================================================
$tenantUsers = Get-AzureADUser -All $true

# verify if external user exists in partnerAD, if not remove from customerAD
ForEach ($tenantUser in $tenantUsers){
    $whitelistExist = DoesUserExistInWhiteList($tenantUser.userPrincipalName) 
    if (-Not $whitelistExist){
        $partnerExist = DoesUserExistInPartnerAD($tenantUser.userPrincipalName)
        $localExist = IsLocalUser($tenantUser.userPrincipalName)
        if ((-Not $partnerExist) -and (-Not $localExist)){
            Write-Host "Remove " $tenantUser.userPrincipalName
            Remove-AzureADUser -ObjectId $tenantUser.ObjectId
            }
        }
} 

# verify if partnerAD user exists in customerAD, if not than create invitation
ForEach ($groupMember in $groupMembers){
    $groupMemberExist = DoesUserExistInTenantAD($groupMember.userPrincipalName) 
    if (-Not $groupMemberExist) { 
        Write-Host "Add " $groupMember.userPrincipalName
        New-AzureADMSInvitation -InvitedUserDisplayName $groupMember.displayName -InvitedUserEmailAddress $groupMember.userPrincipalName -InviteRedirectUrl $InviteRedirectUrl
    }
}

# End Sync external users ============================================================

# Begin Sync groups ==================================================================

$tenantGroups = Get-AzureADGroup -SearchString $groupSearchString -All $true

# verify tenantGroups, if not in partner AD than remove group
ForEach ($tenantGroup in $tenantGroups){
    $tenantGroupExist = DoesTenantGroupExist($tenantGroup.mailNickName)
    if (-Not $tenantGroupExist) { 
        Write-Host "Remove " $tenantGroup.mailNickName
        Remove-AzureADGroup -ObjectId $tenantGroup.ObjectId
        }
    }

# verify partnerGroups, if not in tenant AD than create group
ForEach ($group in $groups){
    $groupExist = DoesPartnerGroupExist($group.mailNickName)
    if (-Not $groupExist) { 
        Write-Host "Add " $group.mailNickName
        New-AzureADGroup -Description $groupDescription -DisplayName $group.mailNickName -MailEnable $false -SecurityEnabled $true -MailNickName $group.mailNickName
        }
    }

# End Sync groups ====================================================================

# Begin Sync group members ===========================================================
$tenantGroups = Get-AzureADGroup -SearchString $groupSearchString -All $true
$tenantUsers = Get-AzureADUser -All $true

#verify tenantGroupMembers against partnerGroupMembers, if not exist remove object from the group
ForEach ($tenantGroup in $tenantGroups){
    $tenantGroupMembers = Get-AzureADGroupMember -ObjectId $tenantGroup.ObjectId -All $true
    ForEach ($tenantGroupMember in $tenantGroupMembers){
        $tenantGroupMemberExist = DoesTenantGroupMemberExist $tenantGroup.MailNickName $tenantGroupMember.userPrincipalName 
        if (-Not $tenantGroupMemberExist) {
            Write-Host "Remove" $tenantGroupMember.userPrincipalName "from" tenantGroup.MailNickName    
            Remove-AzureADGroupMember -ObjectId $tenantGroup.ObjectId -MemberId $tenantGroupMember.ObjectId
        }
    }
}

# build up lookup table
$lookupTenantGroupMembers = New-Object System.Collections.ArrayList
ForEach ($tenantGroup in $tenantGroups) { 
    $members = Get-AzureADGroupMember -ObjectId $tenantGroup.Objectid
    ForEach ($member in $members) { 
    $tempMember = New-Object System.Object
    $tempMember | Add-Member -MemberType NoteProperty -Name "groupObjectId" -Value $tenantGroup.Objectid
    $tempMember | Add-Member -MemberType NoteProperty -Name "groupMailNickName" -Value $tenantGroup.MailNickName
    $tempMember | Add-Member -MemberType NoteProperty -Name "userObjectId" -Value $member.ObjectID
    $tempMember | Add-Member -MemberType NoteProperty -Name "userPrincipalName" -Value $member.userPrincipalName
    $tempMember | Add-Member -MemberType NoteProperty -Name "displayName" -Value $member.displayName
    $lookupTenantGroupMembers.Add($tempMember) | out-null}
}

#verify partnerGroupMembers against tenantGroupMember, if not exist add object to the group
ForEach($groupMember in $groupMembers){
    $partnerGroupMemberExist = DoesPartnerGroupMemberExist($groupMember)
    if (-Not $partnerGroupMemberExist) {
        Write-Host "Add" $groupMember.userPrincipalName "to" $groupMember.groupMailNickName
        $tenantGroupObjectId = GetTenantGroupObjectId($groupMember.groupMailNickName)  
        $tenantUserObjectId = GetTenantUserObjectId($groupMember.userPrincipalName)  
        Add-AzureADGroupMember -ObjectId $tenantGroupObjectId -RefObjectId $tenantUserObjectId
    }
}

# End Sync group members =============================================================

}




