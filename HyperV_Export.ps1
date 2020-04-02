# Set-ExecutionPolicy RemoteSigned
Param([string]$VMID)
<#  
    $ExportPath is the temporary storage space for uncompressed Hyper-V exports.
    If a VM is 500 GB, then the uncompressed Hyper-V export will also be 500 GB.
    $ExportPath must have enough free-space or exports will fail.
    
    $ExportPath is also where log files are saved.

    For performance reasons, $ExportPath should be a different physical storage device
    than the storage device containing Hyper-V VHDX files.

    For example: If drive D: is a SATA SSD containing Hyper-V VHDX files, and drive C: is
    a SATA SSD that does not have enough free-space to save Hyper-V exports, install
    another SATA SSD as drive E: to save Hyper-V exports.

    Or maybe you've got converged storage with 10 gigabit uplinks and don't care.
#>  
$ExportPath = "C:\Users\Public\Documents\Hyper-V\Export"

if (!($VMID)) {
    Write-Host "VMID is required."
    Write-Host $(Get-VM | Select-Object VMName, VMID)
    Write-Host "CMD> ""powershell.exe"" -File ""C:\HyperV_Export.ps1"" -VMID ""9623d59a-a9e9-40cf-a0fd-913248491d50"""
    Write-Host "PowerShell> & ""C:\HyperV_Export.ps1"" -VMID ""9623d59a-a9e9-40cf-a0fd-913248491d50"""
    Exit
}
$DateTimeStart = Get-Date -format "yyyy-MM-dd-THHmm"
try {
    $VMName = $(Get-VM -Id $VMID -ErrorAction Stop).VMName  
}
catch {
    Write-Host $Error[0].Exception.GetType().FullName
    Write-Host $PSItem.ToString()
    Exit
}
$LogFile = "$($ExportPath)\$($VMName)_$($DateTimeStart).log"
Function LogWrite {
    Param ([string]$LogString)
    Add-content $LogFile -value $LogString
    Write-Host $LogString
}

$NetworkDrive = "U:"
$LoopCount = 1
while (1) {
    try {
        # I am not using Test-Path here because Test-Path is frustratingly unreliable with network SMB.
        Set-Content -Path "$($NetworkDrive)\$($DateTimeStart).txt" -Value $DateTimeStart -ErrorAction Stop
        Remove-Item -Path "$($NetworkDrive)\$($DateTimeStart).txt" -Recurse -Force -Confirm:$false -ErrorAction Stop
        LogWrite "Successfully connected drive $($NetworkDrive)\"
        Break
    }
    catch {
        if ($LoopCount -gt 1) {
            LogWrite $($Error[0].Exception.GetType().FullName)
            LogWrite $($PSItem.ToString())
        }
    }
    if ($LoopCount -gt 1) {
        LogWrite "Failed to connect drive $($NetworkDrive)\"
        Exit
    }
    LogWrite "Connecting drive $($NetworkDrive)\"
    try {
        # I am not using New-PSDrive here because New-PSDrive is bafflingly unreliable with network SMB.
        (New-Object -ComObject WScript.Network).MapNetworkDrive($NetworkDrive, "\\169.254.127.127\Hyper-V Exports", $false, "MyServer\MyUsername", "MyPassword")
        # TODO - Implement PSCredential for providing the username and password.
    }
    catch {
        LogWrite $($Error[0].Exception.GetType().FullName)
        LogWrite $($PSItem.ToString())
        Exit
    }
    $LoopCount ++
}

try {
    $State = $(Get-VM -Id $VMID).State
    if ($(Get-VM -Id $VMID).State -eq "paused") {
        LogWrite "Resume $($VMName)"
        Start-VM -Name $VMName -ErrorAction Stop
    }
    if ($(Get-VM -Id $VMID).State -eq "running") {
        LogWrite "Save state of $($VMName)"
        Save-VM -Name $VMName -ErrorAction Stop
    }
    if ($(Get-VM -Id $VMID).State -eq "off" -or $(Get-VM -Id $VMID).State -eq "saved") {
        $DateTimeExport = Get-Date -format "yyyy-MM-dd-THHmm"
        LogWrite "Export $($VMName) to ""$($ExportPath)\$($DateTimeExport)"""
        Export-VM -Name $VMName -Path "$($ExportPath)\$($DateTimeExport)" -ErrorAction Stop
        if ($State -eq "running") {
            LogWrite "Startup $($VMName)"
            Start-VM -Name $VMName -ErrorAction Stop
        }
        $DateTimeUpload = Get-Date -format "yyyy-MM-dd-THHmm"
        LogWrite "Encrypt, compress, and upload ""$($VMName)_$($DateTimeUpload).7z"" to drive $($NetworkDrive)\"
        Start-Process -NoNewWindow -Wait -FilePath "C:\Program Files\7-Zip\7z.exe" -ArgumentList "a", "-ms=on", "-v5119m", "-mx1", "-mmt7", "-p""123456789ABCDEFGHijKLMNoPQRSTUVWXYZ""", """$($NetworkDrive)\$($VMName)\$($VMName)_$($DateTimeUpload).7z""", """$($ExportPath)\$($DateTimeExport)\$($VMName)\*""" -RedirectStandardOutput "$($ExportPath)\$($DateTimeStart)\stdout.log" -RedirectStandardError "$($ExportPath)\$($DateTimeStart)\stderr.log" -ErrorAction Stop
        # TODO - Implement PSCredential for providing the encryption password.
        LogWrite (Get-Content -Path "$($ExportPath)\$($DateTimeStart)\stdout.log")
        $DateTimeStop = Get-Date -format "yyyy-MM-dd-THHmm"
        LogWrite "Upload ended $($DateTimeStop)"
        LogWrite "Cleanup ""$($ExportPath)\$($DateTimeExport)""" 
        Remove-Item "$($ExportPath)\$($DateTimeExport)" -Recurse -Force -Confirm:$false -ErrorAction Stop
    }
}
catch {
    LogWrite $($Error[0].Exception.GetType().FullName)
    LogWrite $($PSItem.ToString())
}
