[CmdletBinding()]
param([string]$DeviceId)

$ErrorActionPreference = 'Stop'

function Select-Emulator {
    param([string[]]$DeviceLines, [string]$Requested)

    $ready = @($DeviceLines | ForEach-Object {
        if ($_ -match '^(emulator-\d+)\s+device(?:\s|$)') { $Matches[1] }
    })
    if ($Requested) {
        if ($Requested -notin $ready) { throw "Emulator '$Requested' is not connected and ready." }
        return $Requested
    }
    if ('emulator-5554' -in $ready) { return 'emulator-5554' }
    if ($ready.Count -eq 1) { return $ready[0] }
    throw 'No unambiguous running emulator. Start one or pass -DeviceId emulator-NNNN.'
}

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit ${LASTEXITCODE}): $Executable $($Arguments -join ' ')"
    }
}

# Dot-sourcing loads only the helpers for the assert-based tests.
if ($MyInvocation.InvocationName -eq '.') { return }

$root = Split-Path -Parent $PSScriptRoot
# Read persisted user settings too: an already-running Pi has an older environment.
foreach ($name in @('FLUTTER_ROOT', 'ANDROID_HOME', 'JAVA_HOME')) {
    if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($value) { [Environment]::SetEnvironmentVariable($name, $value, 'Process') }
    }
}
if (-not $env:FLUTTER_ROOT -or -not $env:ANDROID_HOME -or -not $env:JAVA_HOME) {
    throw 'Set FLUTTER_ROOT, ANDROID_HOME and JAVA_HOME; see docs/DEVELOPER_SETUP.md.'
}
$flutter = Join-Path $env:FLUTTER_ROOT 'bin/flutter.bat'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$java = Join-Path $env:JAVA_HOME 'bin/java.exe'
foreach ($tool in @($flutter, $adb, $java)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing tool: $tool" }
}
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PATH = "$(Split-Path $flutter);$(Split-Path $adb);$(Split-Path $java);$env:PATH"

$devices = @(Invoke-Checked $adb @('devices', '-l'))
$serial = Select-Emulator $devices $DeviceId
$gradle = Get-Content (Join-Path $root 'android/app/build.gradle.kts') -Raw
if ($gradle -notmatch '(?m)^\s*applicationId\s*=\s*"([A-Za-z0-9_.]+)"') {
    throw 'Cannot determine applicationId from android/app/build.gradle.kts.'
}
$appId = $Matches[1]
$apk = Join-Path $root 'build/app/outputs/flutter-apk/app-debug.apk'

Push-Location $root
try {
    Write-Host "Building current working tree for $serial..."
    Invoke-Checked $flutter @('build', 'apk', '--debug')
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) { throw "Build did not produce $apk" }
    Invoke-Checked $adb @('-s', $serial, 'install', '-r', $apk)
    Invoke-Checked $adb @('-s', $serial, 'shell', 'am', 'force-stop', $appId)
    Invoke-Checked $adb @('-s', $serial, 'shell', 'monkey', '-p', $appId, '-c', 'android.intent.category.LAUNCHER', '1')
    Start-Sleep -Seconds 3
    $appProcess = @(Invoke-Checked $adb @('-s', $serial, 'shell', 'pidof', $appId))
    if (-not ($appProcess -join '').Trim()) { throw 'App did not stay running after launch.' }
    Write-Host "PASS: built, installed and running on $serial ($appId)."
    Write-Host 'Still required: visually verify startup and smoke-test the changed flow before completing the iteration.'
} finally {
    Pop-Location
}
