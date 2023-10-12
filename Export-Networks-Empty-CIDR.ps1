<#
Export-Networks-Empty-CIDR.ps1

This script will export a list of vSphere Networks that have been discovered by Aria Automation 
which have not been configured with IP Information.

The script provides a prompt to allow a choice of all networks or networks associated with a 
specific Cloud Account.

Disclaimer:  This script was obtained from https://github.com/cybersylum
  * You are free to use or modify this code for your own purposes.
  * No warranty or support for this code is provided or implied.  
  * Use this at your own risk.  
  * Testing is highly recommended.
#>


# define vars for environment
$vRAServer = "vra8.domain.com"
$vRAUser = "user@domain.com"
$DateStamp=Get-Date -format "yyyyMMdd"
$TimeStamp=Get-Date -format "hhmmss"
$ExportFile = "empty-cidr-networks-$DateStamp-$TimeStamp.csv"

#QueryLimit is used to control the max rows returned by invoke-restmethod (which has a default of 100)
$QueryLimit=9999

$Error.clear()

Write-Host "Connecting to Aria Automation -  $vRAServer as $vRAUser"
$vRA=connect-vraserver -server $vRAServer -Username "$vRAUser" -IgnoreCertRequirements
if ($null -eq $vRA) {
    write-host "Unable to connect to vRA Server '$vRAServer'..."
    exit
}

#Grab the bearer token for use with invoke-restmethod (which is needed for queries with more than 100 results)
$APItoken= $vRA.token | ConvertTo-SecureString -AsPlainText -Force

$Body = @{
    '$top' = $QueryLimit
}
$APIparams = @{
    Method = "GET"
    Uri = "https://$vRAServer/iaas/api/cloud-accounts"
    Authentication = "Bearer"
    Token = $APItoken
    Body = $Body
}

try{
    $CloudAccounts = (Invoke-RestMethod @APIparams -SkipCertificateCheck).Content
} catch {
    Write-Host $("    Unable to get Cloud Accounts from Aria Automation")
    Write-Host $Error
    Write-Host $Error[0].Exception.GetType().FullName
}

Write-Host "Cloud Accounts found - " $CloudAccounts.Count
Write-Host ""
Write-Host "Choose a Cloud Account to use for Network Export:"
$Index=0
foreach ($Account in $CloudAccounts) {
    Write-Host "    " $Index " - " $Account.Name " ("$Account.id")"
    $Index++
}
Write-Host "   99 - All Cloud Accounts"
write-host ""
$Choice= Read-host -Prompt 'Enter selection and hit <ENTER> or just <ENTER> to quit'

if ($Choice.length -eq 0) {
    exit
}

try {
    $Selection = [int]$Choice
}
catch {
    write-host "$Choice is not a valid selection- exiting..."
    exit
}

if ($Selection -ne 99) {
    $InRange = $Selection -In 0..($Index-1)
    if (-Not $InRange) {
        write-host "$Choice is not a valid selection- exiting..."
        exit
    }
}

if ($Selection -eq 99) {
    $DisplayCloudAccountName = "All Cloud Accounts"
    $CloudAccountID = ""
} else {
    $DisplayCloudAccountName = $CloudAccounts[$Selection].name
    $CloudAccountID = $CloudAccounts[$Selection].id
}

#Get All Networks Discovered by vRA - so we can filter later if necessary
$Body = @{
    '$top' = $QueryLimit
}
$APIparams = @{
    Method = "GET"
    Uri = "https://$vRAServer/iaas/api/fabric-networks-vsphere"
    Authentication = "Bearer"
    Token = $APItoken
    Body = $Body
}

try {
    $Networks = (Invoke-RestMethod @APIparams -SkipCertificateCheck).content
} catch {
    Write-Host $("    Unable to get networks from vRA")
    Write-Host $Error
    Write-Host $Error[0].Exception.GetType().FullName
}

write-host "Networks discovered by vRA - " $Networks.count

if ($CloudAccountID -eq "") {
    #Use All Networks discovered by vRA
    $FilteredNetworks = $Networks    
} else {
    #Filter to matching CloudAccount
    $FilteredNetworks = $Networks | where-object -Property cloudAccountIds -eq $CloudAccountID
}

$EmptyNetworks = @()
Write-Host "Scanning networks in $DisplayCloudAccountName for missing IP Info - " $FilteredNetworks.Count 
foreach ($ThisNetwork in $FilteredNetworks) {
   #write-host $ThisNetwork.name " - " $ThisNetwork.cidr
    if ($ThisNetwork.cidr.length -eq "") {
        #write-host $ThisNetwork.name
        $EmptyNetworks += $ThisNetwork.name
    }
}

Write-host "Networks with missing IP info - " $EmptyNetworks.count
 
$EmptyNetworks | out-file -filepath $ExportFile

# Clean up
write-host "list exported to $ExportFile"
Disconnect-vRAServer -Confirm:$false