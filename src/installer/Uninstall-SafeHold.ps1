# ------------------------------------------------------------
# Remove Scheduled Task
# ------------------------------------------------------------
Unregister-ScheduledTask -TaskName "SafeHoldAgent" -Confirm:$false -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# Remove program files
# ------------------------------------------------------------
Remove-Item "C:\Program Files\SafeHold" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\ProgramData\SafeHold" -Recurse -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# Remove registry keys
# ------------------------------------------------------------
Remove-Item "HKCU:\Software\SafeHold\Html"    -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "HKCU:\Software\SafeHold\Backup"  -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "HKCU:\Software\Classes\SafeHold.Redirect" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "SafeHold avinstallert."
