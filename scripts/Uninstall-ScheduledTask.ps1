$taskName = 'Codex-Obsidian-Knowledge-Maintenance'
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Output "Removed scheduled task: $taskName"
