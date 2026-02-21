# Install roles 

Invoke-Command -ComputerName Server001,Server002,Server003 -ScriptBlock { Get-WindowsFeature *hyper*, *failover* , *file-services* , *data-center-bridging* | Install-WindowsFeature -IncludeManagementTools -Restart } 

# Get physical disks of all machines  

invoke-command -computername Server001,Server002,Server003 { get-physicaldisk } | Format-Table pscomputername,friendlyname,size,healthstatus,operationalstatus -AutoSize 

# Configure Networking  

# Ensure NICs are properly named prior to executing. 

New-NetQosPolicy "SMB" -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3 
Enable-NetQosFlowControl -Priority 3 
Disable-NetQosFlowControl -Priority 0,1,2,4,5,6,7 
Get-NetAdapter *admin* | Enable-NetAdapterQos 
New-NetQosTrafficClass "SMB" -Priority 3 -BandwidthPercentage 30 -Algorithm ETS 
New-VMSwitch -Name SETswitch -NetAdapterName "Admin","Admin1" -EnableEmbeddedTeaming $true 
Add-VMNetworkAdapter -SwitchName SETswitch -Name SMB_1 -managementOS 
Add-VMNetworkAdapter -SwitchName SETswitch -Name SMB_2 -managementOS 
Set-VMNetworkAdapterVlan -VMNetworkAdapterName "SMB_1" -VlanId 13 -Access -ManagementOS 
Set-VMNetworkAdapterVlan -VMNetworkAdapterName "SMB_2" -VlanId 13 -Access -ManagementOS 
Get-NetAdapter *SMB* | Restart-NetAdapter 

# If using RDMA capable NICs, uncomment the next linee to enable RDMA on the adapters.

# Get-NetAdapter *SMB* | Enable-NetAdapterRDMA  

Start-Sleep 10 
Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'SMB_1' -ManagementOS -PhysicalNetAdapterName 'ADMIN' 
Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName 'SMB_2' -ManagementOS -PhysicalNetAdapterName 'ADMIN1' 

# Create Cluster  

New-Cluster -Name MyClusterName -Node Server001,Server002,Server003 -NoStorage -staticaddress ClusterIPAddressGoesHere  

# Clean and set up disks  

Invoke-Command (Get-Cluster -Name MyClusterName | Get-ClusterNode){ 
update-StorageProviderCache 
Get-StoragePool | Where-Object IsPrimordial -eq $false | Set-StoragePool -IsReadOnly:$false -ErrorAction SilentlyContinue 
Get-StoragePool | Where-Object IsPrimordial -eq $false | Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false -ErrorAction SilentlyContinue 
Get-StoragePool | Where-Object IsPrimordial -eq $false | Remove-StoragePool -Confirm:$false -ErrorAction SilentlyContinue 
Get-PhysicalDisk | Reset-PhysicalDisk -ErrorAction SilentlyContinue 
Get-Disk | Where-Object Number -ne $null | Where-Object IsBoot -ne $true | Where-Object IsSystem -ne $true | Where-Object PartitionStyle -ne RAW | ForEach-Object { 
    $_ | Set-Disk -isoffline:$false 
    $_ | Set-Disk -isreadonly:$false 
    $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false 
    $_ | Set-Disk -isreadonly:$true 
    $_ | Set-Disk -isoffline:$true 
} 

Get-Disk | Where-Object Number -ne $null | Where-Object IsBoot -ne $true | Where-Object IsSystem -ne $true |Where-Object PartitionStyle -eq RAW | Group-Object -NoElement -Property FriendlyName } | Sort-Object -Property PsComputerName,Count 
Enable-ClusterStorageSpacesDirect -CimSession MyClusterName 

# Create Cluster Shared Volume 

New-Volume -FriendlyName "Volume1" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName S2D* -Size 150TB 

# Configure paths for Hyper-V  

# Use Configure-PathsPoolHolder.ps1 on the node currently holding the pool, and Configure-PathsNonPoolHolder.ps1 on the other nodes.

# To-do: Add code to automatically detect which node is currently holding the pool and configure paths accordingly.
