$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$import = Join-Path $root 'scripts\Import-CodexSessions.ps1'
$compile = Join-Path $root 'scripts\Compile-Knowledge.ps1'
$temp = Join-Path $env:TEMP 'CodexObsidianKnowledgeReleaseTest'
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
$vault = Join-Path $temp 'vault'
$sessions = Join-Path $temp 'sessions'
@('00_Inbox\Codex-Auto-Capture\Review','00_Inbox\Codex-Auto-Capture\Conflicts','90_System\Memory\Run-Logs','10_Projects\Demo') | ForEach-Object { New-Item -ItemType Directory -Path (Join-Path $vault $_) -Force | Out-Null }
New-Item -ItemType Directory -Path $sessions -Force | Out-Null
@{ schema_version = 1; updated_at = $null; sessions = @() } | ConvertTo-Json | Set-Content (Join-Path $vault '90_System\Memory\Import-State.json') -Encoding UTF8
@{ schema_version = 1; updated_at = $null; entries = @() } | ConvertTo-Json | Set-Content (Join-Path $vault '90_System\Memory\Content-Index.json') -Encoding UTF8
'{"project":"Demo","type":"note","statement":"fixture","text":"mail=a@example.com 13800138000"}' | Set-Content (Join-Path $sessions 'fixture.jsonl') -Encoding UTF8
. $import -Mode Library -VaultPath $vault -SessionPath $sessions
$redacted = Get-RedactedText 'a@example.com 13800138000'
if ($redacted -notmatch 'REDACTED:EMAIL' -or $redacted -notmatch 'REDACTED:PHONE') { throw 'Redaction failed' }
& $import -Mode Fixture -VaultPath $vault -SessionPath $sessions | Out-Null
$review = @(Get-ChildItem (Join-Path $vault '00_Inbox\Codex-Auto-Capture\Review') -File -Filter '*.md')
if ($review.Count -ne 1) { throw 'Fixture import failed' }
$text = Get-Content -Raw -Encoding UTF8 $review[0].FullName
$text = $text -replace 'approval_status: review','approval_status: approved' -replace 'privacy_status: required','privacy_status: cleared'
[IO.File]::WriteAllText($review[0].FullName,$text,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $vault '10_Projects\Demo\Project-Status.md'),'# Demo',[Text.UTF8Encoding]::new($false))
& $compile -VaultPath $vault -Apply | Out-Null
if (-not (Get-Content -Raw -Encoding UTF8 (Join-Path $vault '10_Projects\Demo\Project-Status.md')).Contains('BEGIN MANAGED:')) { throw 'Compile failed' }
Write-Output 'PASS: knowledge pipeline fixture'
