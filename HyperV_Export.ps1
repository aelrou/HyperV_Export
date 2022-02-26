# Set-ExecutionPolicy RemoteSigned
# Unblock-File -Path "C:\HyperV_Export.ps1"
# "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "C:\HyperV_Export.ps1"
Param ([string]$VMID)
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

try {
    $VMName = $(Get-VM -Id $VMID -ErrorAction Stop).VMName  
}
catch {
    Write-Host $Error[0].Exception.GetType().FullName
    Write-Host $PSItem.ToString()
    Exit
}

$FORMAT_ISO_8601 = "yyyy-MM-ddTHHmmss"
$REGEX_ISO_8601 = "\d{4}-\d{2}-\d{2}T\d{2}\d{2}\d{2}"
$DateTimeStart = Get-Date -format $FORMAT_ISO_8601 #$DateTimeStart = Get-Date -format "yyyy-MM-dd-THH-mm"
$LogFile = "$($VMName)_$($DateTimeStart).log"

if (!(Test-Path -Path "$($ExportPath)\$($LogFile)" -PathType Leaf)) {
    if (!(Test-Path -Path "$($ExportPath)" -PathType Container)) {
        try {
            New-Item -Path "$($ExportPath)" -ItemType "directory" -ErrorAction Stop
        }
        catch {
            Write-Host($Error[0].Exception.GetType().FullName)
            Write-Host($PSItem.ToString())
            Exit
        }
    }
}
Function LogWrite {
    Param ([string]$LogString)
    Add-content "$($ExportPath)\$($LogFile)" -value $LogString
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
        # TODO - Implement PSCredential for providing the network drive credentials.
    }
    catch {
        LogWrite $($Error[0].Exception.GetType().FullName)
        LogWrite $($PSItem.ToString())
        Exit
    }
    $LoopCount ++
}

$Upload = $false
$OriginalState = $(Get-VM -Id $VMID).State
$DateTimeExport = Get-Date -format $FORMAT_ISO_8601

$LoopCount = 1
while (1) {
    try {
        $CurrentState = $(Get-VM -Id $VMID).State
        if ($CurrentState -eq "paused") {
            LogWrite "Resume $($VMName)"
            Start-VM -Name $VMName -ErrorAction Stop
        }
        if ($CurrentState -eq "running") {
            LogWrite "Live export $($VMName) to ""$($ExportPath)\$($DateTimeExport)"""
            Export-VM -Name $VMName -Path "$($ExportPath)\$($DateTimeExport)" -ErrorAction Stop
            $Upload = $true
            Break
        }
        if ($CurrentState -eq "off" -or $CurrentState -eq "saved") {
            LogWrite "Export $($VMName) to ""$($ExportPath)\$($DateTimeExport)"""
            Export-VM -Name $VMName -Path "$($ExportPath)\$($DateTimeExport)" -ErrorAction Stop
            $Upload = $true
            Break
        }
    }
    # TODO - Implement catch and procedure for non-live exports.
    catch {
        LogWrite $($Error[0].Exception.GetType().FullName)
        LogWrite $($PSItem.ToString())  
    }
    if ($LoopCount -gt 3) {
        LogWrite "Failed to export $($VMName)"
        Break
    }
    else {
        Start-Sleep -Seconds 1
        $LoopCount ++    
    }
}

if ($OriginalState -eq "running" -and $(Get-VM -Id $VMID).State -ne "running") {
    try {
        LogWrite "Resume $($VMName)"
        Start-VM -Name $VMName -ErrorAction Stop
    }
    catch {
        LogWrite $($Error[0].Exception.GetType().FullName)
        LogWrite $($PSItem.ToString())
    }
}                

if ($Upload) {
    try {
        $DateTimeUpload = Get-Date -format $FORMAT_ISO_8601
        LogWrite "Encrypt, compress, and upload ""$($VMName)_$($DateTimeUpload).7z"" to drive $($NetworkDrive)\"
        Start-Process -NoNewWindow -Wait -FilePath "C:\Program Files\7-Zip\7z.exe" -ArgumentList "a", "-ms=on", "-v5119m", "-mx1", "-mmt7", "-p""123456789ABCDEFGHijKLMNoPQRSTUVWXYZ""", """$($NetworkDrive)\$($VMName)\$($VMName)_$($DateTimeUpload).7z""", """$($ExportPath)\$($DateTimeExport)\$($VMName)\*""" -RedirectStandardOutput "$($ExportPath)\$($DateTimeExport)\stdout.log" -RedirectStandardError "$($ExportPath)\$($DateTimeExport)\stderr.log" -ErrorAction Stop
        # TODO - Implement PSCredential for providing the encryption password.
        LogWrite (Get-Content -Path "$($ExportPath)\$($DateTimeExport)\stdout.log")
        $DateTimeStop = Get-Date -format $FORMAT_ISO_8601
        LogWrite "Upload ended $($DateTimeStop)"
    }
    catch {
        LogWrite $($Error[0].Exception.GetType().FullName)
        LogWrite $($PSItem.ToString())
    }    
}

if ($Upload) {
    try {
        LogWrite "Cleanup ""$($ExportPath)\$($DateTimeExport)""" 
        Remove-Item "$($ExportPath)\$($DateTimeExport)" -Recurse -Force -Confirm:$false -ErrorAction Stop
    }
    catch {
        LogWrite $($Error[0].Exception.GetType().FullName)
        LogWrite $($PSItem.ToString())
    }    
}
