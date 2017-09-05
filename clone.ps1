# team vXTreme
#
# VMworld Hackathon 2017

Import-Module VMware.PowerCLI

# normally I wouldn't have creds in the script, but we didn't get the slack bot working and needed an automated way to initiate the clone of the VMs
$vCenter = ""
$vCenterUser = ""
$vCenterPwd = ""


$connect = Connect-VIServer $vCenter -User $vCenterUser -Password $vCenterPwd

# get a list of production VMs
$blueFolder = Get-vm -lo Blue | ? {$_.Name -notmatch "clone"}
$greenFolder = get-vm -lo green | ? {$_.Name -notmatch "clone"}

# determine which is currently production, blue or green
if($blueFolder.length -gt "0"){$prodVMs = $blueFolder; $prodEnv = "Blue"; $stageEnv = "Green"}
If($greenFolder.length -gt "0"){$prodVMs = $greenFolder; $prodEnv = "Green"; $stageEnv = "Blue"}

# grab the necessary port groups
$prodPG = Get-VDSwitch vds-R720 | Get-VDPortgroup | ? {$_.name -match $prodEnv} | ? {$_.name -notmatch "Transit"}
$stagePG = Get-VDSwitch vds-R720 | Get-VDPortgroup | ? {$_.name -match $stageEnv} | ? {$_.name -notmatch "Transit"}

# now lets do some stuff
foreach ($i in $prodVMs){
    
    $newname = $i.Name+"-clone"
    # clone existing production VM
    new-vm -VMHost $i.VMHost -Name $newname -Location (Get-Folder $stageEnv) -Datastore (Get-Datastore -VM $i) -VM $i
    
    # change the vNIC to the other Logical Switch on the staging edge
    Get-NetworkAdapter $newname | Set-NetworkAdapter -Portgroup $stagePG -Confirm:$false

    # Power on the VM
    Start-VM $newname -Confirm:$false
    
    # connect the vNIC
    Get-NetworkAdapter $newname | Set-NetworkAdapter -Connected:$true -Confirm:$false
}

Disconnect-VIServer -Confirm:$false