# HyperV_Export
PowerShell script to export, encrypt, compress, and upload a Hyper-V VM backup

Native Hyper-V export is not the most robust backup strategy, but it **is** reliable and subscription-free.

Permit running PowerShell scripts on a host: *PowerShell* `Set-ExecutionPolicy RemoteSigned` Then `Y` to confirm  
Display a list of VMID: *PowerShell* `Get-VM | Select-Object VMName, VMID`  
Run a script: *CMD* `"powershell.exe" -File "C:\HyperV_Export.ps1" -VMID "9623d59a-a9e9-40cf-a0fd-913248491d50"`  
Run a script: *PowerShell* `& "C:\HyperV_Export.ps1" -VMID "9623d59a-a9e9-40cf-a0fd-913248491d50"`  

This PowerShell script is designed to run as a scheduled task with Administrative privileges on Windows Server 2012. To ensure that scheduled exports continue if a VM name changes, a VMID is used instead of a VMName. It has also been tested on Server 2012 **R2**, Server 2016, Server 2019, and Server 2022.

Live exports are not supported on Windows Server 2012 *(not R2)*, so a VM must be saved or shutdown before export. This script saves and exports a VM, then starts it again if it was running originally.

This script is designed to connect to a network drive, preferably using credentials of an account in the Backup Operator group.

Once an export is complete and the network drive is connected, [7-Zip](https://www.7-zip.org/) is used to encrypt and compress the export while uploading it to the network drive in a [4.99 GB](https://www.backblaze.com/b2/docs/large_files.html) split-file archive. After that it deletes the uncompressed export.  

# Please review and update as necessary:  
 - The $ExportPath directory: `"C:\Users\Public\Documents\Hyper-V\Export"`  
 - The $NetworkDrive letter: `"U:"`  
 - The network drive path: `"\\169.254.127.127\Hyper-V Exports"`  
 - The network drive username and password: `"MyServer\MyUsername", "MyPassword"`  
 - The 7-Zip thread count: `"-mmt7"` uses 7 CPU cores. `"-mmt4"` uses 4 cores or 50% of an 8-core CPU.  
 - The 7-Zip encryption password (keep the double "" quotation marks): `""123456789ABCDEFGHijKLMNoPQRSTUVWXYZ""`  

Live exports which are supported on Server 2012 **R2**, Server 2016, Server 2019, and Server 2022
