# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
$root = "C:\Program Files\SafeHold"
$log  = "C:\ProgramData\SafeHold"
$htmlRoot = "HKCU:\Software\SafeHold\Html"

# ------------------------------------------------------------
# Create folders
# ------------------------------------------------------------
New-Item -Path $root -ItemType Directory -Force | Out-Null
New-Item -Path $log  -ItemType Directory -Force | Out-Null

# ------------------------------------------------------------
# Copy program files
# ------------------------------------------------------------
Copy-Item ".\SafeHoldLauncher.ps1" "$root\SafeHoldLauncher.ps1" -Force
Copy-Item ".\SafeHoldAgent.ps1"    "$root\SafeHoldAgent.ps1"    -Force

# ------------------------------------------------------------
# Create global HTML templates (Pre/Post)
# ------------------------------------------------------------
if (-not (Test-Path $htmlRoot)) {
    New-Item -Path $htmlRoot -Force | Out-Null
}

$pre = @"
<!DOCTYPE html>
<html lang="no">
<head>
<meta charset="UTF-8">
<title>SafeHold</title>
<style>
body { font-family: Segoe UI, sans-serif; margin: 30px; background: #fafafa; }
.box { border: 1px solid #ccc; padding: 20px; border-radius: 8px; background: white; max-width: 520px; margin: auto; }
h1 { font-size: 20px; margin-bottom: 10px; }
p { margin: 5px 0; }
.btn { display: inline-block; margin-top: 15px; padding: 8px 16px; background: #0078d4; color: white; border-radius: 4px; text-decoration: none; }
</style>
</head>
<body>
<div class="box">
<h1>SafeHold – Filtype blokkert</h1>
"@

$post = @"
</div>
</body>
</html>
"@

Set-ItemProperty -Path $htmlRoot -Name Pre  -Value $pre
Set-ItemProperty -Path $htmlRoot -Name Post -Value $post

# ------------------------------------------------------------
# Register Scheduled Task (runs every 15 minutes)
# ------------------------------------------------------------
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -File `"$root\SafeHoldAgent.ps1`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)

Register-ScheduledTask -TaskName "SafeHoldAgent" -Action $action -Trigger $trigger -RunLevel Highest -Force

Write-Host "SafeHold installert."
