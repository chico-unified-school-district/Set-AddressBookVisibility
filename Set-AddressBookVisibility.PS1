
<#
.SYNOPSIS
In a hybrid Excahnge environment this process is intended to ensure
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
 [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 2 })]
 [string]$DomainController,
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
 Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $DomainController) -Fore Green
 $adCmdLets = 'Get-ADUser', 'Set-ADUser'
 $adSession = New-PSSession -ComputerName $DomainController -Credential $ADCredential
 Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber | Out-Null
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
. .\lib\Clear-SessionData.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun
Clear-SessionData

Get-ADData | Select-Accounts | Clear-msExchHideFromAddressLists

Clear-SessionData
Show-TestRun