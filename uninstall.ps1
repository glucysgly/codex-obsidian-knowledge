param([switch]$TaskOnly)
& (Join-Path $PSScriptRoot 'scripts\Uninstall-ScheduledTask.ps1')
if (-not $TaskOnly) { Write-Output 'Runtime packages can be removed manually; Vault and Codex sessions are intentionally preserved.' }
