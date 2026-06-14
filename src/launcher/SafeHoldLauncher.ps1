param(
    [Parameter(Mandatory=$true)]
    [string]$File
)

# ------------------------------------------------------------
# Helper: Write fallback message using msg.exe
# ------------------------------------------------------------
function Write-FallbackMessage {
    param([string]$Text)
    $escaped = $Text -replace '"','\"'
    Start-Process -FilePath "msg.exe" -ArgumentList "* `"$escaped`"" -WindowStyle Hidden
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
# Determine extension
# ------------------------------------------------------------
$ext = [System.IO.Path]::GetExtension($File).TrimStart('.').ToLower()
if (-not $ext) {
    Write-FallbackMessage "SafeHold: Kunne ikke bestemme filtype for $File"
    exit
}

# ------------------------------------------------------------
# Read DNS policy
# ------------------------------------------------------------
$policyFqdn = "$ext.safehold.internal.test"
$txt = Get-TxtRecord $policyFqdn

if (-not $txt) {
    Write-FallbackMessage "SafeHold: Ingen policy for *.$ext*. Filen åpnes ikke via SafeHold."
    exit
}

$policy = @{}
foreach ($p in $txt -split ';') {
    $kv = $p.Trim() -split '=', 2
    if ($kv.Length -eq 2) { $policy[$kv[0]] = $kv[1] }
}

$status = $policy['status']

# ------------------------------------------------------------
# If status != hold → SafeHoldLauncher does not open files
# ------------------------------------------------------------
if ($status -ne 'hold') {
    Show-FallbackMessage "SafeHold: Filtypen *.$ext* er ikke blokkert. SafeHoldLauncher åpner ikke filer direkte."
    exit
}

# ------------------------------------------------------------
# Load HTML templates from registry
# ------------------------------------------------------------
$htmlRoot = "HKCU:\Software\SafeHold\Html"
$backupKey = "HKCU:\Software\SafeHold\Backup\$ext"

try {
    $pre  = (Get-ItemProperty $htmlRoot -ErrorAction Stop).Pre
    $post = (Get-ItemProperty $htmlRoot -ErrorAction Stop).Post
    $body = (Get-ItemProperty $backupKey -ErrorAction Stop).HtmlBody
}
catch {
    Write-FallbackMessage "SafeHold: HTML-mal mangler for *.$ext*. Kontakt administrator."
    exit
}

# ------------------------------------------------------------
# Build full HTML
# ------------------------------------------------------------
$fullHtml = $pre + "`n" + $body + "`n" + $post

# ------------------------------------------------------------
# Write HTML to temp file
# ------------------------------------------------------------
$temp = Join-Path $env:TEMP "safehold_$ext.html"
Set-Content -Path $temp -Value $fullHtml -Encoding UTF8

# ------------------------------------------------------------
# Try to open in Edge
# ------------------------------------------------------------
try {
    $tempPath = (Get-Item $temp).FullName
    $fileUri = "file:///$($tempPath -replace '\\','/')"
    Start-Process -FilePath "msedge.exe" -ArgumentList $fileUri -ErrorAction Stop
}
catch {
    try {
        Start-Process -FilePath $temp -ErrorAction Stop
    }
    catch {
        Write-FallbackMessage "SafeHold: Filtypen *.$ext* er blokkert, men Edge og standard nettleser kunne ikke åpnes."
    }
}

exit
