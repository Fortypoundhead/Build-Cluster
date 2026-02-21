# Install roles 

Invoke-Command -ComputerName Server001,Server002,Server003 -ScriptBlock { Get-WindowsFeature *hyper*, *failover* , *file-services* , *data-center-bridging* | Install-WindowsFeature -IncludeManagementTools -Restart } 

# get physical disks of all machines  

invoke-command -computername Server001,Server002,Server003 { get-physicaldisk } | ft pscomputername,friendlyname,size,healthstatus,operationalstatus -AutoSize 

# Configure Networking  

# Ensure NICs are properly named prior to executing. Needs to be Admin and Admin1 

New-NetQosPolicy "SMB" –NetDirectPortMatchCondition 445 –PriorityValue8021Action 3 
Enable-NetQosFlowControl –Priority 3 
Disable-NetQosFlowControl –Priority 0,1,2,4,5,6,7 
Get-NetAdapter *admin* | Enable-NetAdapterQos 
New-NetQosTrafficClass "SMB" –Priority 3 –BandwidthPercentage 30 –Algorithm ETS 
New-VMSwitch –Name SETswitch –NetAdapterName "Admin","Admin1" –EnableEmbeddedTeaming $true 
Add-VMNetworkAdapter –SwitchName SETswitch –Name SMB_1 –managementOS 
Add-VMNetworkAdapter –SwitchName SETswitch –Name SMB_2 –managementOS 
Set-VMNetworkAdapterVlan -VMNetworkAdapterName "SMB_1" -VlanId 13 -Access -ManagementOS 
Set-VMNetworkAdapterVlan -VMNetworkAdapterName "SMB_2" -VlanId 13 -Access -ManagementOS 
Get-NetAdapter *SMB* | Restart-NetAdapter 

# Get-NetAdapter *SMB* | Enable-NetAdapterRDMA  

Start-Sleep 10 
Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'SMB_1' –ManagementOS –PhysicalNetAdapterName 'ADMIN' 
Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'SMB_2' –ManagementOS –PhysicalNetAdapterName 'ADMIN1' 

# Create Cluster  

New-Cluster –Name MyClusterName –Node Server001,Server002,Server003 -NoStorage -staticaddress ClusterIPAddressGoesHere  

# Clean and set up disks  

Invoke-Command (Get-Cluster -Name MyClusterName | Get-ClusterNode){ 
update-StorageProviderCache 
Get-StoragePool | Where-Object IsPrimordial -eq $false | Set-StoragePool -IsReadOnly:$false -ErrorAction SilentlyContinue 
Get-StoragePool | Where-Object IsPrimordial -eq $false | Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false -ErrorAction SilentlyContinue 
Get-StoragePool | Where-Object IsPrimordial -eq $false | Remove-StoragePool -Confirm:$false -ErrorAction SilentlyContinue 
Get-PhysicalDisk | Reset-PhysicalDisk -ErrorAction SilentlyContinue 
Get-Disk | Where-Object Number -ne $null | Where-Object IsBoot -ne $true | Where-Object IsSystem -ne $true | Where-Object PartitionStyle -ne RAW | % { 
    $_ | Set-Disk -isoffline:$false 
    $_ | Set-Disk -isreadonly:$false 
    $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false 
    $_ | Set-Disk -isreadonly:$true 
    $_ | Set-Disk -isoffline:$true 
} 

Get-Disk | Where-Object Number -ne $null | Where-Object IsBoot -ne $true | Where-Object IsSystem -ne $true |Where-Object PartitionStyle -eq RAW | Group -NoElement -Property FriendlyName } | Sort -Property PsComputerName,Count 
Enable-ClusterStorageSpacesDirect –CimSession MyClusterName 

# Create Volume 

New-Volume -FriendlyName "Volume1" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName S2D* -Size 150TB 

# Configure paths for Hyper-V  

# Create default VM and VHD paths. This needs to be run on the node that is currently holding the pool 

Get-VMHost | fl * 
$VMDRIVE = "C:" 
$VMPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V" 
$VHDPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V\VirtualHardDisks"` 
MD -Path $VMPath,$VHDPath 
Set-VMHost -VirtualHardDiskPath $VHDPath -VirtualMachinePath $VMPath  
Get-VMHost | fl * 

# Point the nodes at the default VM and VHD paths. This needs to be run on all other nodes 

Get-VMHost | fl * 
$VMDRIVE = "C:" 
$VMPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V" 
$VHDPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V\VirtualHardDisks" 
Set-VMHost -VirtualHardDiskPath $VHDPath -VirtualMachinePath $VMPath  
Get-VMHost | fl * 
