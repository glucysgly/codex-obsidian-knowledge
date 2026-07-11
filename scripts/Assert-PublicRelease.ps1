param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [switch]$FixturePrivate
)

$ErrorActionPreference = 'Stop'
$fixture = Join-Path $RootPath 'private-fixture.txt'
if ($FixturePrivate) {
    $privatePath = 'C:' + '\' + 'Users' + '\example\private'
    [System.IO.File]::WriteAllText($fixture, $privatePath, [System.Text.UTF8Encoding]::new($false))
}

$markers = @(
    ('C:' + '\' + 'Users' + '\'),
    ('wx' + 'id_'),
    ('api' + '_key=')
)
$hits = @()
$files = Get-ChildItem -LiteralPath $RootPath -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\.git\\' -and
    $_.FullName -notmatch '\\tests\\' -and
    $_.FullName -ne $PSCommandPath
}
foreach ($file in $files) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    foreach ($marker in $markers) {
        if ($text.Contains($marker)) { $hits += "$($file.FullName):$marker" }
    }
    if ($text -match 'sk-[A-Za-z0-9]{16,}') { $hits += "$($file.FullName):token" }
    if ($text -match '(?<!\d)1[3-9]\d{9}(?!\d)') { $hits += "$($file.FullName):phone" }
}
if ($FixturePrivate) { Remove-Item -LiteralPath $fixture -Force }
if ($hits.Count) { throw "PUBLIC RELEASE GUARD FAILED: $($hits -join '; ')" }
