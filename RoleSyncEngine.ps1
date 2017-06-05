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
$cred = Get-AutomationPSCredential -Name 'RoleSync-SyncAccount'
}
else
{
$partnerId = "xxxxx-c1e1-42d0-xxxxxxxxxxx"
$groupSearchString = "_myprefix-"
$InviteRedirectUrl = "http://www.microsoft.com"
$groupDescription = "Automated group creation - Do not remove or do not change"
$User = "xxxx@xxxxxxxxx.onmicrosoft.com"
$PWord = ConvertTo-SecureString -String "xxxxxxxxxxx" -AsPlainText -Force
$cred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord
}

if (($partnerId -eq $null) -or ($groupSearchString -eq $null)  -or ($InviteRedirectUrl -eq $null) -or ($groupDescription -eq $null) -or ($cred -eq $null)) {
    Write-Host "Variables validation failed"
    exit 2
}

Write-Host "Script version" $version
$customRoleDefinitions = New-Object System.Collections.ArrayList
$customRoleDefinitions.Add($groupSearchString+"VM Contributor:Microsoft.Compute/virtualMachines/*") | out-null
$customRoleDefinitions.Add($groupSearchString+"Support Contributor:Microsoft.Support/*") | out-null

$roleAssignmentDefinitions = New-Object System.Collections.ArrayList
$roleAssignmentDefinitions.Add($groupSearchString+"Support_Engineer:Reader") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Support_Engineer:"+$groupSearchString+"VM Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Support_Engineer:"+$groupSearchString+"Support Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Dynamics_Engineer:Reader") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Dynamics_Engineer:Virtual Machine Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Reader") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Backup Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Classic Network Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Classic Storage Account Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Monitoring Contributor Service Role") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Network Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Security Manager") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:Storage Account Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:"+$groupSearchString+"VM Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"MS_Infra_Engineer:"+$groupSearchString+"Support Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Reader") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Backup Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Classic Network Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Classic Storage Account Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Network Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Security Manager") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Storage Account Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:Traffic Manager Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:"+$groupSearchString+"VM Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Platform_Engineer:"+$groupSearchString+"Support Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"Cloud_Solution_Architect:Owner") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"IM_CM_PM:Reader") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"IM_CM_PM:"+$groupSearchString+"Support Contributor") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"DevOps_RnD:Reader") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"DevOps_RnD:Automation Operator") | out-null
$roleAssignmentDefinitions.Add($groupSearchString+"DevOps_RnD:DevTest Labs User") | out-null


Connect-AzureAD -TenantId $partnerId -Credential $cred

# Get all contracts
$contracts = Get-AzureADContract -All $true

# functions
function DoesRoleAssignmentExistInDefinitions( [string] $groupName, [string] $roleName)
{
    ForEach($roleAssignmentDefinition in $roleAssignmentDefinitions){
        if ($roleAssignmentDefinition.ToLower().Equals($groupName+":"+$roleName)){
            return $true
        }
    }

    return $false
}

function DoesRoleAssignmentExist ([string] $roleName, [string] $groupName)
{

ForEach ($roleAssignment in $roleAssignments){
    if (($roleAssignment.DisplayName.ToLower().Equals($groupName.ToLower()) -and ($roleAssignment.RoleDefinitionName.ToLower().Equals($roleName.ToLower())))) {
        return $true
        }
}

return $false
}

function DoesCustomRoleExist ([string] $roleName)
{

ForEach ($roleDefinition in $roleDefinitions){
    if ($roleName.ToLower().Equals($roleDefinition.Name.ToLower())){ return $true}
}

return $false
}

function CreateCustomRole ([string] $roleName, [string] $actions)
{
    $role = Get-AzureRmRoleDefinition -Name "Virtual Machine Contributor"
    $role.Id = $null
    $role.Name = $roleName
    $role.Description = "Custom Role Definition."
    $role.Actions.RemoveRange(0,$role.Actions.Count)
    ForEach ($action in $actions.Split(',')){ $role.Actions.Add($action) }
    $role.AssignableScopes.Remove("/") | Out-Null
    ForEach ($tempSubscription in $subscriptions){
    if ($tempSubscription.State -eq 'Enabled') {
        $role.AssignableScopes.Add("/subscriptions/"+$tempSubscription.SubscriptionId)}
        }
    New-AzureRmRoleDefinition -Role $role
}


ForEach($contract in $contracts){
Login-AzureRmAccount -Credential $cred -TenantId $contract.CustomerContextId | out-null
Connect-AzureAD -Credential $cred -TenantId $contract.CustomerContextId | out-null

$subscriptions = Get-AzureRMSubscription -TenantId $contract.CustomerContextId

ForEach ($subscription in $subscriptions) {

if ($subscription.State -eq 'Enabled') {

# Select Azure Subscription
Select-AzureRmSubscription -SubscriptionId $subscription.SubscriptionId -TenantId $contract.CustomerContextId

#verify the existence of the custom role, if not exist create
$roleDefinitions = Get-AzureRMRoleDefinition -Scope ("/subscriptions/"+$subscription.SubscriptionId) -Custom
ForEach ($customRoleDefinition in $customRoleDefinitions) {
    if ((DoesCustomRoleExist $customRoleDefinition.Split(':')[0]) -eq $false){
        Write-Host "Create role" $customRoleDefinition.Split(':')[0]
        CreateCustomRole $customRoleDefinition.Split(':')[0] $customRoleDefinition.Split(':')[1]
    }
}

#refresh role definitions
$roleDefinitions = Get-AzureRMRoleDefinition -Scope ("/subscriptions/"+$subscription.SubscriptionId)

#verify subscription role assignments for prefixed groups against lookup table, if not in lookup table than remove assignment
$roleAssignments = Get-AzureRmRoleAssignment
ForEach ($roleAssignment in $roleAssignments) {
    if (($roleAssignment.ObjectType -eq 'Group') -and ($roleAssignment.DisplayName.ToLower().StartsWith($groupSearchString))){
        if ((DoesRoleAssignmentExistInDefinitions $roleAssignment.DisplayName.ToLower() $roleAssignment.RoleDefinitionName.ToLower()) -eq $false){
            Write-Host "Remove role" $roleAssignment.RoleDefinitionName "from" $roleAssignment.DisplayName
            Remove-AzureRMRoleAssignment -ObjectId $roleAssignment.ObjectId -RoleDefinitionName $roleAssignment.RoleDefinitionName    
        }
    }
}

#refresh list of Role Assignments
$roleAssignments = Get-AzureRmRoleAssignment

#iterate through the list of roleassignmentdefinitions, verify if exists, if not than create role assignment
ForEach($roleAssignmentDefinition in $roleAssignmentDefinitions){
    if ((DoesRoleAssignmentExist $roleAssignmentDefinition.ToString().Split(':')[1] $roleAssignmentDefinition.ToString().Split(':')[0]) -eq $false){
        Write-Host "Add role" $roleAssignmentDefinition.ToString().Split(':')[1] "to" $roleAssignmentDefinition.ToString().Split(':')[0]

        $groupObjectId = Get-AzureADGroup -SearchString $roleAssignmentDefinition.ToString().Split(':')[0]
        $scope = "/subscriptions/"+$subscription.SubscriptionId
        New-AzureRmRoleAssignment -ObjectId $groupObjectId.ObjectId -RoleDefinitionName $roleAssignmentDefinition.ToString().Split(':')[1] -Scope $scope
    }
}
}
}
}
