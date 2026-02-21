# Configure default VM and VHD paths on the node CURRENTLY HOLDING THE POOL.

Get-VMHost | Format-List * 
$VMDRIVE = "C:" 
$VMPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V" 
$VHDPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V\VirtualHardDisks" 
mkdir -Path $VMPath,$VHDPath 
Set-VMHost -VirtualHardDiskPath $VHDPath -VirtualMachinePath $VMPath  
Get-VMHost | Format-List * 