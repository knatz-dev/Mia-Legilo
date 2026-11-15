$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/deploy-emulator.ps1"

function Assert-Equal($Expected, $Actual) {
    if ($Expected -ne $Actual) { throw "Expected '$Expected', got '$Actual'." }
}
function Assert-Throws([scriptblock]$Action) {
    $threw = $false
    try { & $Action } catch { $threw = $true }
    if (-not $threw) { throw 'Expected an error.' }
}

$devices = @('List of devices attached', 'emulator-5556 device product:test', 'emulator-5554 device product:test', 'phone-123 device')
Assert-Equal 'emulator-5554' (Select-Emulator $devices)
Assert-Equal 'emulator-5556' (Select-Emulator $devices 'emulator-5556')
Assert-Equal 'emulator-5556' (Select-Emulator @('emulator-5556 device'))
Assert-Throws { Select-Emulator @('emulator-5554 offline', 'phone-123 device') }
Assert-Throws { Select-Emulator @('emulator-5556 device', 'emulator-5558 device') }
Assert-Throws { Select-Emulator $devices 'phone-123' }
Assert-Throws { Select-Emulator $devices 'emulator-9999' }
Assert-Throws { Select-Emulator @() }

# Exercise native exit-code propagation without Flutter, ADB or an emulator.
$powerShell = (Get-Process -Id $PID).Path
Invoke-Checked $powerShell @('-NoProfile', '-Command', 'exit 0')
Assert-Throws { Invoke-Checked $powerShell @('-NoProfile', '-Command', 'exit 7') }
Write-Host 'PASS: emulator selection and command failure checks.'
