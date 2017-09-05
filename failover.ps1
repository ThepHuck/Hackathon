# team vXTreme
#
# VMworld Hackathon 2017

Import-Module VMware.PowerCLI
Import-Module PowerNSX

$nsxMgr = ""
$nsxPwd = ""
$vCenter = ""
$vCenterUser = ""
$vCenterPwd = ""

$connectvCenter = Connect-VIServer $vCenter -User $vCenterUser -Password $vCenterPwd
Connect-NsxServer $nsxMgr -Username admin -Password $nsxPwd

# get the location of the clones
$blueFolder = Get-vm -lo Blue | ? {$_.Name -match "-clone"}
$greenFolder = get-vm -lo green | ? {$_.Name -match "-clone"}

# now we need to set which is old production and which will take over as production
if($blueFolder){$newProdVMs = $blueFolder; $oldProdVMs = get-vm -lo green | ? {$_.Name -notmatch "-clone"}; $prodEnv = "Green"; $stageEnv = "Blue"}
If($greenFolder){$newProdVMs = $greenFolder; $oldProdVMs = Get-vm -lo Blue | ? {$_.Name -notmatch "-clone"}; $prodEnv = "Blue"; $stageEnv = "Green"}

# setting the ESG names
$parentNSXEdge = "hackathon-parent"
$stageNSXEdge = "hackathon-$stageEnv"
$prodNSXEdge = "hackathon-$prodEnv"

# get existing routes and their vnic & next hop, will need them to flip traffic
$ProdRoutes = Get-NsxEdge $parentNSXEdge | Get-NsxEdgeRouting | Get-NsxEdgeStaticRoute | ? {$_.description -imatch "Production"}
$CloneRoutes = Get-NsxEdge $parentNSXEdge | Get-NsxEdgeRouting | Get-NsxEdgeStaticRoute | ? {$_.description -imatch "Clone"}

$oldProdNextHop = ($ProdRoutes | ?{$_.description -imatch "Production"}).nextHop
$oldProdVnic = ($ProdRoutes | ?{$_.description -imatch "Production"}).vnic

$oldCloneNextHop = ($CloneRoutes | ?{$_.description -imatch "Clone"}).nextHop
$oldCloneVnic = ($CloneRoutes | ?{$_.description -imatch "Clone"}).vnic

# assemble the new routes
$newProdNextHop = (get-NsxEdge $stageNSXEdge | get-nsxedgeinterface | ?{$_.portgroupName -eq "Hackathon-$stageEnv-Transit"}).addressgroups.addressgroup.Primaryaddress
$newProdVnic = (get-NsxEdge $parentNSXEdge | get-nsxedgeinterface | ?{$_.portgroupName -eq "Hackathon-$stageEnv-Transit"}).index

$newCloneNextHop = (get-NsxEdge $prodNSXEdge | get-nsxedgeinterface | ?{$_.portgroupName -eq "Hackathon-$prodEnv-Transit"}).addressgroups.addressgroup.Primaryaddress
$newCloneVnic = (get-NsxEdge $parentNSXEdge | get-nsxedgeinterface | ?{$_.portgroupName -eq "Hackathon-$prodEnv-Transit"}).index

# remove all current routes
$ProdRoutes | Remove-NsxEdgeStaticRoute -Confirm:$false
$CloneRoutes | Remove-NsxEdgeStaticRoute -Confirm:$false

# build new static routes
foreach ($i in $ProdRoutes){
    $nextHop = $null
    $vnic = $null
    $nextHop = $newProdNextHop
    $vnic = $newProdVnic
    Get-NsxEdge $parentNSXEdge | Get-NsxEdgeRouting | New-NsxEdgeStaticRoute -NextHop $nextHop -Vnic $vnic -Network $i.network -Description $i.description -Confirm:$false
}

foreach ($i in $CloneRoutes){
    $nextHop = $null
    $vnic = $null
    $nextHop = $newCloneNextHop
    $vnic = $newCloneVnic
    Get-NsxEdge $parentNSXEdge | Get-NsxEdgeRouting | New-NsxEdgeStaticRoute -NextHop $nextHop -Vnic $vnic -Network $i.network -Description $i.description -Confirm:$false
}


# I was having problems with setting the NAT rules for some reason, so I skipped this part, was wasn't particularly needed for the demo, anyway.
#$natrules = Get-NsxEdge $stageNSXEdge | Get-NsxEdgeNat | Get-NsxEdgeNatRule
#$natrules = Remove-NsxEdgeNatRule -Confirm:$false

#foreach ($i in $natrules){
#    Get-NsxEdge $prodNSXEdge | Get-NsxEdgeNat | New-NsxEdgeNatRule -OriginalAddress $i.originalAddress -TranslatedAddress $i.translatedAddress -action $i.action
#}
# end nat rule fail

# removes the old production VMs
foreach ($i in $oldProdVMs){
    Get-VM $i | Stop-VM -Confirm:$false | Remove-VM -DeletePermanently -Confirm:$false
}

# renames the cloned VMs to be production
foreach ($i in $newProdVMs){
    set-vm $i -Name $i.Name.Split("-clone")[0] -Confirm:$false
}


Disconnect-VIServer -Confirm:$false