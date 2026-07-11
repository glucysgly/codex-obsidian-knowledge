param([switch]$FixturePrivate)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$guard = Join-Path $root 'scripts\Assert-PublicRelease.ps1'
$fixture = Join-Path $root 'private-fixture.txt'
if ($FixturePrivate) { [System.IO.File]::WriteAllText($fixture, 'private fixture', [System.Text.UTF8Encoding]::new($false)) }
try {
    & $guard -RootPath $root -FixturePrivate:$FixturePrivate
    if ($FixturePrivate) { throw 'Private fixture was not rejected' }
    Write-Output 'PASS: public release guard'
}
finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Force }
}
