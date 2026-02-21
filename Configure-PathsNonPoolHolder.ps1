# Configure default VM and VHD paths on nodes NOT HOLDING THE POOL.

Get-VMHost | Format-List * 
$VMDRIVE = "C:" 
$VMPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V" 
$VHDPath = Join-Path -Path $VMDRIVE -ChildPath "ClusterStorage\Volume1\Hyper-V\VirtualHardDisks" 
Set-VMHost -VirtualHardDiskPath $VHDPath -VirtualMachinePath $VMPath  
Get-VMHost | Format-List * 