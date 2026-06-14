param(
    [string]$LauncherPath = 'C:\Program Files\SafeHold\SafeHoldLauncher.ps1',
    [string]$LogFile      = 'C:\ProgramData\SafeHold\agent.log',
    [string]$DomainBase   = 'safehold.internal.test'
)

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
function Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force -ErrorAction SilentlyContinue | Out-Null
    Add-Content -Path $LogFile -Value "$timestamp $Message"
}

# ------------------------------------------------------------
# DNS TXT lookup
# ------------------------------------------------------------
function Get-TxtRecord {
    param([string]$Fqdn)
    $out = nslookup -type=TXT $Fqdn 2>$null
    foreach ($line in $out) {
        if ($line -match 'text =') {
            if ($line -match '"(.*)"') {
                return $matches[1]
            }
        }
    }
    return $null
}

# ------------------------------------------------------------
# Registry helpers
# ------------------------------------------------------------
function Get-CurrentAssociation {
    param([string]$Ext)
    $paths = @(
        "HKCU:\Software\Classes\.$Ext",
        "HKLM:\Software\Classes\.$Ext",
        "HKCR:\.$Ext"
    )
    foreach ($p in $paths) {
        try {
            $val = (Get-ItemProperty -Path $p -ErrorAction SilentlyContinue).'(default)'
            if ($val) { return $val }
        } catch {}
    }
    return $null
}

function Initialize-RedirectProgId {
    param([string]$LauncherPath)

    $progIdKey = "HKCU:\Software\Classes\SafeHold.Redirect"
    $shellKey  = "$progIdKey\shell\open\command"

    if (-not (Test-Path $progIdKey)) {
        New-Item -Path $shellKey -Force | Out-Null
        $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$LauncherPath`" -File `"%1`""
        Set-ItemProperty -Path $shellKey -Name '(default)' -Value $cmd
        Log "Opprettet ProgID SafeHold.Redirect"
    }
}

# ------------------------------------------------------------
# HTML global templates (Pre/Post)
# ------------------------------------------------------------
function Initialize-GlobalHtmlTemplates {

    $htmlRoot = "HKCU:\Software\SafeHold\Html"
    if (-not (Test-Path $htmlRoot)) {
        New-Item -Path $htmlRoot -Force | Out-Null
    }

    $preExists  = (Get-ItemProperty $htmlRoot -ErrorAction SilentlyContinue).Pre
    $postExists = (Get-ItemProperty $htmlRoot -ErrorAction SilentlyContinue).Post

    if (-not $preExists) {
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
        Set-ItemProperty -Path $htmlRoot -Name Pre -Value $pre
        Log "Opprettet global Pre-HTML"
    }

    if (-not $postExists) {
        $post = @"
</div>
</body>
</html>
"@
        Set-ItemProperty -Path $htmlRoot -Name Post -Value $post
        Log "Opprettet global Post-HTML"
    }
}

# ------------------------------------------------------------
# Build midt-HTML for extension
# ------------------------------------------------------------
function New-HtmlBody {
    param(
        [string]$Ext,
        [hashtable]$Policy
    )

    $reason = $Policy['reason']
    $alt    = $Policy['alt']
    $url    = $Policy['url']

    $reasonHtml = if ($reason) { "<p>Årsak: $reason</p>" } else { "<p>Årsak: Ikke oppgitt</p>" }
    $altHtml    = if ($alt)    { "<p><strong>Alternativ:</strong> $alt</p>" } else { "" }
    $urlHtml    = if ($url)    { "<a class=""btn"" href=""$url"" target=""_blank"">Mer info</a>" } else { "" }

    return ($reasonHtml + "`n" + $altHtml + "`n" + $urlHtml)
}

# ------------------------------------------------------------
# Redirect / restore
# ------------------------------------------------------------
function Set-Redirect {
    param(
        [string]$Ext,
        [hashtable]$Policy,
        [string]$LauncherPath
    )

    $backupKey = "HKCU:\Software\SafeHold\Backup\$Ext"
    $extKey    = "HKCU:\Software\Classes\.$Ext"

    # Backup original ProgID
    if (-not (Test-Path $backupKey)) {
        $current = Get-CurrentAssociation -Ext $Ext
        New-Item -Path $backupKey -Force | Out-Null
        Set-ItemProperty -Path $backupKey -Name 'ProgID' -Value $current
        Log "Backup: .$Ext -> $current"
    }

    # Lagre midt-HTML
    $body = New-HtmlBody -Ext $Ext -Policy $Policy
    Set-ItemProperty -Path $backupKey -Name HtmlBody -Value $body

    # Sørg for at redirect-progid finnes
    Initialize-RedirectProgId -LauncherPath $LauncherPath

    # Sett redirect
    New-Item -Path $extKey -Force | Out-Null
    Set-ItemProperty -Path $extKey -Name '(default)' -Value 'SafeHold.Redirect'
    Log "Redirect satt for .$Ext"
}

function Restore-Association {
    param([string]$Ext)

    $backupKey = "HKCU:\Software\SafeHold\Backup\$Ext"
    $extKey    = "HKCU:\Software\Classes\.$Ext"

    if (Test-Path $backupKey) {
        $props  = Get-ItemProperty -Path $backupKey -ErrorAction SilentlyContinue
        $progId = $props.ProgID

        if ($progId) {
            New-Item -Path $extKey -Force | Out-Null
            Set-ItemProperty -Path $extKey -Name '(default)' -Value $progId
            Log "Restored: .$Ext -> $progId"
        } else {
            Remove-Item -Path $extKey -Recurse -Force -ErrorAction SilentlyContinue
            Log "Fjernet override for .$Ext (ingen tidligere ProgID)"
        }

        Remove-Item -Path $backupKey -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    # Stray redirect
    try {
        $current = (Get-ItemProperty -Path $extKey -ErrorAction SilentlyContinue).'(default)'
        if ($current -eq 'SafeHold.Redirect') {
            Remove-Item -Path $extKey -Recurse -Force -ErrorAction SilentlyContinue
            Log "Fjernet stray redirect for .$Ext"
        }
    } catch {}
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------
Log "SafeHoldAgent start"

# Sørg for global HTML-ramme
Initialize-GlobalHtmlTemplates

# Hent liste over extensions
$extensionsFqdn = "extensions.$DomainBase"
$extListTxt = Get-TxtRecord $extensionsFqdn

if (-not $extListTxt) {
    Log "DNS-feil: $extensionsFqdn svarte ikke. Agent gjør ingenting."
    exit
}

$extensions = $extListTxt -split ';' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }

# Behandle hver extension
foreach ($ext in $extensions) {
    $fqdn = "$ext.$DomainBase"
    $txt  = Get-TxtRecord $fqdn
    if (-not $txt) {
        Log "Ingen policy for $fqdn"
        continue
    }

    $policy = @{}
    foreach ($p in $txt -split ';') {
        $kv = $p.Trim() -split '=', 2
        if ($kv.Length -eq 2) { $policy[$kv[0]] = $kv[1] }
    }

    if ($policy['status'] -eq 'hold') {
        Set-Redirect -Ext $ext -Policy $policy -LauncherPath $LauncherPath
    }
    else {
        Restore-Association -Ext $ext
        Log "Policy for .$ext er ikke HOLD"
    }
}

# Rydd opp extensions som ikke lenger er i DNS-listen
$handledBefore = @()
if (Test-Path 'HKCU:\Software\SafeHold\Backup') {
    $handledBefore = Get-ChildItem 'HKCU:\Software\SafeHold\Backup' | Select-Object -ExpandProperty PSChildName
}

$toCleanup = $handledBefore | Where-Object { $_ -notin $extensions }
foreach ($ext in $toCleanup) {
    Log "Extension .$ext finnes ikke lenger i DNS-listen – restore."
    Restore-Association -Ext $ext
}

Log "SafeHoldAgent ferdig"