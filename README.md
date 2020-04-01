# HyperV_Export
PowerShell script to export, encrypt, compress, and upload a Hyper-V virtual machine

Native Hyper-V export is not the most robust backup strategy, but it's free.

This PowerShell script is designed to run as a scheduled task with Administrative privileges on Windows Server 2012.

Live exports do not seem to be supported on Windows Server 2012 (not R2), so a VM must be either saved or shutdown in order to export it. This script saves and exports a VM, then starts it again if it was running originally.

To ensure that scheduled exports continue if a VM name gets changed, this script requires a VMID argument instead of a VM name.

This script is designed to connect to a network drive, preferably using credentials of an account in the Backup Operator group.

Once the export is complete and the network drive is connected, this script uses 7-Zip to encrypt and compress the export while uploading it to the network drive in 4.99 GB archive split-files. After that it deletes the uncompressed export.

**Make sure review and update:**
*The $ExportPath directory: `"C:\Users\Public\Documents\Hyper-V\Export"`
*The $NetworkDrive letter: `"U:"`
*The network drive path: `"\\169.254.127.127\Hyper-V Exports"`
*The network drive Backup Operator username and password: `"MyServer\MyUsername", "MyPassword"`
*The 7-Zip encryption password (keep the double-double quotation marks): `""123456789ABCDEFGHijKLMNoPQRSTUVWXYZ""`

With some modification this script can do live exports which are supported on Server 2016 and Server 2019.
