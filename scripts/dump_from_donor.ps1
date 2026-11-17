# Pulls DeviceAsWebcam from a phone that ships with it (for example a Galaxy S26 Ultra)
# into module/system. No root needed on the donor.
#
#   .\scripts\dump_from_donor.ps1 -Serial <donor serial from "adb devices">

param(
    [Parameter(Mandatory = $true)][string]$Serial,
    [string]$Adb = "adb"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root "module\system\priv-app\DeviceAsWebcam"
$lib = Join-Path $root "module\system\lib64"
New-Item -ItemType Directory -Force $app, $lib | Out-Null

$path = (& $Adb -s $Serial shell pm path com.android.DeviceAsWebcam) -replace "^package:", ""
if (-not $path) { throw "com.android.DeviceAsWebcam is not installed on $Serial" }
Write-Host "APK on donor: $path"

& $Adb -s $Serial pull $path.Trim() (Join-Path $app "DeviceAsWebcam.apk")
& $Adb -s $Serial pull /system/lib64/libjni_deviceAsWebcam.so (Join-Path $lib "libjni_deviceAsWebcam.so")

Write-Host ""
Write-Host "Donor build:  $(& $Adb -s $Serial shell getprop ro.build.fingerprint)"
Write-Host "Donor SDK:    $(& $Adb -s $Serial shell getprop ro.build.version.sdk)"
Write-Host "Compare the SDK with your target phone (adb shell getprop ro.build.version.sdk)."
