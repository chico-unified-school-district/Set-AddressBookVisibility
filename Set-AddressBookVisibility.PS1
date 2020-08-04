
<# 
.SYNOPSIS			
 Bradford requires a specific AD User Account Control flag be set to determine if an account has access
 to various CUSD network services. The User Account Control flag for disable dobjects is 0x0202. 
 A Powershell script is used to search AD for qualifying disabled user objects and set the flag.
 This process runs every 30 minutes as a scheduled task.
.DESCRIPTION
 A PSSession is created with an account with access to a domain controller and write/change permisssions on user objects.
.EXAMPLE
.\Set-UACFlag.PS1 -DomainController 'myDC' -ADCredential $CredentialObject
.EXAMPLE
.\Set-UACFlag.PS1 -DomainController 'myDC' -ADCredential $CredentialObject -WhatIf -Verbose
.INPUTS
.OUTPUTS
.NOTES
#>

[cmdletbinding()]
param ( 
 [Parameter(Mandatory = $True)]
 [Alias('DC')]
 [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
 [string]$DomainController,
 # PSSession to Domain Controller and Use Active Directory CMDLETS  
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [SWITCH]$WhatIf 
)

Clear-Host; $error.clear() # Clear Screen and $error
Get-PSSession | Remove-PSSession -WhatIf:$false

. .\lib\Add-Log.ps1

# AD Domain Controller Session
$adCmdLets = 'Get-ADUser', 'Set-ADUser'
$adSession = New-PSSession -ComputerName $DomainController -Credential $ADCredential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber > $null
$StaffOU = 'OU=Employees,OU=Users,OU=Domain_Root,DC=chico,DC=usd'

# Processing
$waitTime = 60 # Minutes
$endTime = '6:00pm'
Add-Log script ("Running every $waitTime minutes until $(Get-Date $endTime -f HH:mm)") $WhatIf
do {
 $users = $null
 Write-Verbose 'Getting qualifying AD Users'
 $users = Get-ADUser -Filter {
  (employeeID -like "*") -and
  (mail -like "*@chicousd.org")
 } -SearchBase $StaffOU -Properties employeeID, msExchHideFromAddressLists,title |
  Where-Object {
   ($_.msExchHideFromAddressLists -eq 'True') -and
   ($_.employeeID -match "\d{4,}") -and
   (($_.title -notlike "*generic*") -or ($_.title -notlike "*service*"))
  }
  $users.count
 if ($users) {
  foreach ($obj in $users) {
   Add-log update ('{0},Clearing msExchHideFromAddressLists' -f $obj.samAccountName) $WhatIf
   Set-ADUser -Identity $obj.ObjectGUID -Clear msExchHideFromAddressLists -Confirm:$false -WhatIf:$WhatIf
  }
 }
 if (!$WhatIf) {
  Write-Verbose ('Sleeping for {0} minutes...' -f $waitTime)
  Start-Sleep ($waitTime * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge (Get-Date $endTime)) )

Write-Verbose "Tearing down sessions"
Get-PSSession | Remove-PSSession -WhatIf:$false