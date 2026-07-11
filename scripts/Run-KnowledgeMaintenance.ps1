param(
    [Parameter(Mandatory = $true)][string]$VaultPath,
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [Parameter(Mandatory = $true)][string]$RuntimePath,
    [ValidateRange(1, 365)][int]$RetentionDays = 7
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $VaultPath -PathType Container)) { throw "Vault not found: $VaultPath" }
if (-not (Test-Path -LiteralPath $SessionPath -PathType Container)) { throw "Sessions not found: $SessionPath" }
New-Item -ItemType Directory -Path $RuntimePath -Force | Out-Null
$lockPath = Join-Path $RuntimePath 'maintenance.lock'
try {
    $lock = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
}
catch { Write-Output 'SKIP: maintenance already running'; exit 0 }
try {
    $env:CODEX_OBSIDIAN_RUNTIME = $RuntimePath
    $env:CODEX_ALLOW_ALL_IMPORT = 'CONFIRMED'
    & (Join-Path $PSScriptRoot 'Import-CodexSessions.ps1') -Mode All -VaultPath $VaultPath -SessionPath $SessionPath
    Get-ChildItem -LiteralPath (Join-Path $RuntimePath 'packages') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -lt (Get-Date).ToUniversalTime().AddDays(-$RetentionDays) } |
        Remove-Item -Recurse -Force
}
finally {
    Remove-Item Env:CODEX_OBSIDIAN_RUNTIME -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_ALLOW_ALL_IMPORT -ErrorAction SilentlyContinue
    $lock.Dispose()
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}
