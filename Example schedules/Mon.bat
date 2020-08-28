rem SERVERONE
start "Z" /b /wait "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "C:\HyperV_Export.ps1" -VMID "9623d59a-a9e9-40cf-a0fd-913248491d50"

rem SERVERTWO
start "Z" /b /wait "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "C:\HyperV_Export.ps1" -VMID "623d59a9-9e9a-0cf4-0fda-13248491d509"
