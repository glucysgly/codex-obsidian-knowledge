param(
    [string]$VaultPath,
    [string]$SessionPath = (Join-Path $HOME '.codex\sessions'),
    [string]$RuntimePath,
    [switch]$InstallSchedule
)

$ErrorActionPreference = 'Stop'
if (-not $VaultPath) { $VaultPath = Read-Host 'Obsidian Vault path' }
if (-not $RuntimePath) { $RuntimePath = if (Test-Path 'D:\') { 'D:\CodexObsidianRuntime' } else { Join-Path $env:LOCALAPPDATA 'CodexObsidianRuntime' } }
if (-not (Test-Path -LiteralPath $VaultPath -PathType Container)) { throw "Vault not found: $VaultPath" }
if (-not (Test-Path -LiteralPath $SessionPath -PathType Container)) { throw "Sessions not found: $SessionPath" }
$dirs = @('00_Inbox\Codex-Auto-Capture\Review','00_Inbox\Codex-Auto-Capture\Approved','00_Inbox\Codex-Auto-Capture\Rejected','00_Inbox\Codex-Auto-Capture\Conflicts','10_Projects','20_Knowledge','90_System\Memory\Run-Logs')
$dirs | ForEach-Object { New-Item -ItemType Directory -Path (Join-Path $VaultPath $_) -Force | Out-Null }
foreach ($name in @('AGENTS.md','Workspace-Map.yaml')) {
    $target = if ($name -eq 'AGENTS.md') { Join-Path $VaultPath $name } else { Join-Path $VaultPath "90_System\$name" }
    if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "templates\$name") -Destination $target }
}
New-Item -ItemType Directory -Path $RuntimePath -Force | Out-Null
if ($InstallSchedule) { & (Join-Path $PSScriptRoot 'scripts\Install-ScheduledTask.ps1') -VaultPath $VaultPath -SessionPath $SessionPath -RuntimePath $RuntimePath }
Write-Output "Installed. Run .\scripts\Run-KnowledgeMaintenance.ps1 manually or use -InstallSchedule."
