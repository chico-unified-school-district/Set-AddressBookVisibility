
<#
.SYNOPSIS
In a hybrid Exchange environment this process is intended to ensure
that Active Directory accounts are properly displayed in the Office 365 Global Address Book.
.DESCRIPTION
Clears the 'msExchHideFromAddressLists' attribute for active staff accounts.
 A PSSession is created with an account with access to a domain controller and write/change permisssions on user objects.
.EXAMPLE
.\Set-AddressBookVisibility.PS1 -DomainController 'DC.contra.org' -ADCredential $CredentialObject -OU 'OU=Employees,OU=Users,DC=contra,DC=org' -Staff -Students
.EXAMPLE
.\Set-AddressBookVisibility.PS1 -DomainController 'DC.contra.org' -ADCredential $CredentialObject -OU 'OU=Employees,OU=Users,DC=contra,DC=org' -Staff -Students -WhatIf -Verbose
.INPUTS
.OUTPUTS
.NOTES
#>

[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)]
 [Alias('DC')]
 [string[]]$DomainControllers,
 # PSSession to Domain Controller and Use Active Directory CMDLETS
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory = $True)]
 [string]$StaffOrgUnit,
 [string]$StudentOrgUnit,
 [switch]$Staff,
 [switch]$Students,
 [Alias('wi')]
 [SWITCH]$WhatIf
)

function Get-Disabled {
 process {
  if ($_.Enabled -eq $False) { $_ }
 }
}

function Get-Enabled {
 process {
  if ($_.Enabled -eq $True) { $_ }
 }
}

function Get-ADDAta ($ou) {
 $params = @{
  Filter     = "employeeId -like '*'"
  SearchBase = $ou
  Properties = 'msExchHideFromAddressLists', 'EmployeeId', 'Mail', 'Title', 'AccountExpirationDate'
 }
 $data = Get-ADUser @params
 Write-Host ('{0},{1},Count: {2}' -f $MyInvocation.MyCommand.Name, $ou.Split('OU=')[1].Trim(','), @($data).count) -Fore Green
 $data
}

function Select-Accounts {
 process {
  if (($_.EmployeeID -match "\d{4,}") -and ($_.Title -notlike "*generic*") -and ($_.Title -notlike "*service*")) { $_ }
 }
}

function Set-AddressBookHide {
 begin { $i = 0 }
 process {
  if ($_.msExchHideFromAddressLists -eq $true) { return }
  Write-Verbose ($_ | Out-String)
  $msgData = $MyInvocation.MyCommand.Name, $_.employeeId, $_.samAccountName, $_.msExchHideFromAddressLists
  Write-Host ('{0},{1},{2},Old Value: [{3}]' -f $msgData ) -Fore Magenta
  Set-ADUser -Identity $_.ObjectGUID -Replace @{msExchHideFromAddressLists = $true } -Confirm:$false -WhatIf:$WhatIf
  $i++
 }
 end { Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, $i) -f Magenta }
}

function Set-AddressBookShow {
 begin { $i = 0 }
 process {
  if ($_.msExchHideFromAddressLists -ne $true) { return }
  Write-Verbose ($_ | Out-String)
  $msgData = $MyInvocation.MyCommand.Name, $_.employeeId, $_.samAccountName, $_.msExchHideFromAddressLists
  Write-Host ('{0},{1},{2},Old Value: [{3}]' -f $msgData ) -Fore Green
  Set-ADUser -Identity $_.ObjectGUID -Clear msExchHideFromAddressLists -Confirm:$false -WhatIf:$WhatIf
 }
 end { Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, $i) -f Green }
}

# ========================== Main ===============================
Import-Module -Name 'CommonScriptFunctions'

Show-BlockInfo Start
if ($WhatIf) { Show-TestRun }

Connect-ADSession -DomainControllers $DomainControllers -Credential $ADCredential -Cmdlets 'Get-ADUser', 'Set-ADUser'

if ($Staff) {
 $staffData = Get-ADData $StaffOrgUnit
 $staffData | Select-Accounts | Get-Disabled | Set-AddressBookHide
 $staffData | Select-Accounts | Get-Enabled | Set-AddressBookShow
}

if ($Students) {
 $studentData = Get-ADData $StudentOrgUnit
 $studentData |  Select-Accounts | Get-Disabled | Set-AddressBookHide
 $studentData |  Select-Accounts | Get-Enabled | Set-AddressBookShow
}

Clear-SessionData
if ($WhatIf) { Show-TestRun }
Show-BlockInfo End