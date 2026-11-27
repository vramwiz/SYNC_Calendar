param(
    [string]$PluginPath = 'C:\ProgramData\aviutl2\Plugin\SYNC_Calendar\SYNC_Calendar.auf2',
    [string]$MeshDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compiler = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe'
$out = Join-Path $root 'Win64\CalendarTests'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$plugin = (Resolve-Path -LiteralPath $PluginPath).Path

Push-Location $PSScriptRoot
try {
    & $compiler -B -Q "-E$out" "-N$out" Calendar_RenderTests.dpr
    if ($LASTEXITCODE -ne 0) { throw "Calendar_RenderTests compilation failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}
$exe = Join-Path $out 'Calendar_RenderTests.exe'
& $exe $plugin $MeshDirectory
if ($LASTEXITCODE -ne 0) { throw "Calendar_RenderTests failed ($LASTEXITCODE)" }
