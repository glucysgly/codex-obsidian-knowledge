param(
    [Parameter(Mandatory = $true)][string]$VaultPath,
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [Parameter(Mandatory = $true)][string]$RuntimePath
)

$taskName = 'Codex-Obsidian-Knowledge-Maintenance'
$runner = Join-Path $PSScriptRoot 'Run-KnowledgeMaintenance.ps1'
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -VaultPath `"$VaultPath`" -SessionPath `"$SessionPath`" -RuntimePath `"$RuntimePath`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description 'Imports completed Codex sessions into Obsidian Review.' -Force | Out-Null
Write-Output "Installed scheduled task: $taskName"
