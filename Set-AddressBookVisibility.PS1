
<#
.SYNOPSIS
In a hybrid Exchange environment this process is intended to ensure
that Active Directory accounts for current staff are visible in the Office 365 Global Address Book.
.DESCRIPTION
Clears the 'msExchHideFromAddressLists' attribute for active staff accounts.
 A PSSession is created with an account with access to a domain controller and write/change permisssions on user objects.
.EXAMPLE
.\Set-AddressBookVisibility.PS1 -DomainController 'DC.contra.org' -ADCredential $CredentialObject -OU 'OU=Employees,OU=Users,DC=contra,DC=org'
.EXAMPLE
.\Set-AddressBookVisibility.PS1 -DomainController 'DC.contra.org' -ADCredential $CredentialObject -OU 'OU=Employees,OU=Users,DC=contra,DC=org' -WhatIf -Verbose
.INPUTS
.OUTPUTS
.NOTES
#>

[cmdletbinding()]
param (
   [Parameter(Mandatory = $True)]
   [Alias('DC')]
   [string[]]$DomainController,
   # PSSession to Domain Controller and Use Active Directory CMDLETS
   [Parameter(Mandatory = $True)]
   [System.Management.Automation.PSCredential]$ADCredential,
   [Parameter(Mandatory = $True)]
   [Alias('OU')]
   [string]$StaffOrgUnit,
   [Alias('wi')]
   [SWITCH]$WhatIf
)

function Get-ADData {
   Write-Host ('{0}' -f $MyInvocation.MyCommand.Name) -Fore Green
   $aDparams = @{
      Filter     = "employeeId -like `'*`' -and mail -like `'*@*`' -and Enabled -eq `'True`'-and msExchHideFromAddressLists -like `'*`'"
      SearchBase = $StaffOrgUnit
      Properties = 'msExchHideFromAddressLists', 'employeeId', 'mail', 'title', 'AccountExpirationDate'
   }
   Get-ADUser @aDparams
}

function Clear-msExchHideFromAddressLists {
   process {
      Write-Verbose ($_ | Out-String)
      $msgData = $MyInvocation.MyCommand.Name, $_.employeeId, $_.samAccountName, $_.msExchHideFromAddressLists
      Write-Host ('{0},{1},{2},Old Value: [{3}]' -f $msgData ) -Fore Yellow
      Set-ADUser -Identity $_.ObjectGUID -Clear msExchHideFromAddressLists -Confirm:$false -WhatIf:$WhatIf
   }
}

filter Select-Accounts {
   $_ | Where-Object {
  ($_.employeeID -match "\d{4,}") -and
  (($_.title -notlike "*generic*") -or ($_.title -notlike "*service*"))
   }
}

# ========================== Main ===============================
Import-Module -Name 'CommonScriptFunctions'

Show-BlockInfo Start
if ($WhatIf) { Show-TestRun }

Connect-ADSession -DomainControllers $DomainController -Credential $ADCredential -Cmdlets 'Get-ADUser', 'Set-ADUser'

Get-ADData | Select-Accounts | Clear-msExchHideFromAddressLists

Clear-SessionData
if ($WhatIf) { Show-TestRun }
Show-BlockInfo End