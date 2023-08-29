#Exports list of Newtorks that do not have CIDR filled out

# define vars for environment
$DateStamp=Get-Date -format "yyyyMMdd"
$TimeStamp=Get-Date -format "hhmmss"
$ExportFile = "empty-cidr-networks-$DateStamp-$TimeStamp.csv"
$vRAServer = "vra8.cybersylum.com"
$vRAUser = "kinger@cybersylum.com"

$vRA=connect-vraserver -server $vRAServer -Username "$vRAUser" -IgnoreCertRequirements
if ($null -eq $vRA) {
    write-host "Unable to connect to vRA Server '$vRAServer'..."
    exit
}

$EmptyNetworks = ""
$Networks = (Invoke-vRARestMethod -Method GET -URI "/iaas/api/networks" -WebRequest).content | ConvertFrom-JSON -AsHashtable

write-host "Exporting list of Networks with no CIDR defined to $ExportFile"

foreach ($Network in $Networks.content) {
   # write-host $Network.name " - " $Network.cidr
    if ($Network.cidr.length -eq "") {
        #write-host $Network.name
        $EmptyNetworks += $Network.name
        $EmptyNetworks += "`n"
    }
}
 
$EmptyNetworks | out-file -filepath $ExportFile

# Clean up
Disconnect-vRAServer -Confirm:$false