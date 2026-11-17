# Builds DeviceAsWebcam_ksu.zip from module/.
# Compress-Archive writes backslash paths on Windows PowerShell, which KernelSU
# extracts as literal file names, so the entries are written by hand here.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "module"
$zip = Join-Path $root "DeviceAsWebcam_ksu.zip"

foreach ($f in "system\priv-app\DeviceAsWebcam\DeviceAsWebcam.apk", "system\lib64\libjni_deviceAsWebcam.so") {
    if (-not (Test-Path (Join-Path $src $f))) { throw "Missing module\$f - run scripts\dump_from_donor.ps1 first" }
}

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip }
$z = [IO.Compression.ZipFile]::Open($zip, "Create")
try {
    Get-ChildItem $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1).Replace("\", "/")
        if ($rel.EndsWith(".sh") -or $rel -eq "module.prop") {
            # Shell scripts must have LF line endings on Android
            $text = [IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n")
            $entry = $z.CreateEntry($rel)
            $w = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
            $w.Write($text); $w.Close()
        } else {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $_.FullName, $rel)
        }
    }
} finally { $z.Dispose() }

[IO.Compression.ZipFile]::OpenRead($zip).Entries | ForEach-Object FullName
Write-Host "Built $zip"
