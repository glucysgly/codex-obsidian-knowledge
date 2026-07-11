param(
    [ValidateSet('Library', 'Fixture', 'Pilot', 'All')]
    [string]$Mode = 'Library',
    [int]$PilotCount = 5,
    [string]$VaultPath = '',
    [string]$SessionPath = ''
)

$ErrorActionPreference = 'Stop'

function Get-Sha256Text([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Get-SharedFileHash([string]$Path) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-SessionInventory([string]$SessionPath) {
    if (-not (Test-Path -LiteralPath $SessionPath -PathType Container)) { throw "Session path does not exist: $SessionPath" }
    $root = (Get-Item -LiteralPath $SessionPath).FullName.TrimEnd('\')
    return @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.jsonl' | ForEach-Object {
        $file = $_
        $method = 'Get-FileHash'
        try { $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash }
        catch { $hash = Get-SharedFileHash $file.FullName; $method = 'SharedReadSnapshot' }
        $fresh = Get-Item -LiteralPath $file.FullName
        [pscustomobject]@{
            FullName = $fresh.FullName
            RelativePath = $fresh.FullName.Substring($root.Length).TrimStart('\')
            Length = $fresh.Length
            LastWriteTimeUtc = $fresh.LastWriteTimeUtc.ToString('o')
            Sha256 = $hash.ToLowerInvariant()
            HashMethod = $method
        }
    })
}

function Read-JsonlSafe([string]$Path) {
    $lineNumber = 0
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
    try {
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                [pscustomobject]@{ ok = $true; line_number = $lineNumber; value = ($line | ConvertFrom-Json -ErrorAction Stop); error_type = $null }
            }
            catch {
                [pscustomobject]@{ ok = $false; line_number = $lineNumber; value = $null; error_type = 'invalid_json' }
            }
        }
    }
    finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-RedactedText([string]$Text) {
    if ($null -eq $Text) { return '' }
    $result = $Text
    $result = [regex]::Replace($result, '(?<!\d)\d{17}[0-9Xx](?!\d)', '[REDACTED:PRC_ID]')
    $result = [regex]::Replace($result, '(?<!\d)1[3-9]\d{9}(?!\d)', '[REDACTED:PHONE]')
    $result = [regex]::Replace($result, '(?i)(?<![\w.+-])[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}(?![\w.-])', '[REDACTED:EMAIL]')
    $result = [regex]::Replace($result, '(住院号|门诊号|病历号|病案号)\s*[:：=]?\s*[A-Za-z0-9-]+', '[REDACTED:MEDICAL_ID]')
    $result = [regex]::Replace($result, '(?i)sk-[A-Za-z0-9_-]{12,}', '[REDACTED:SECRET]')
    $result = [regex]::Replace($result, '(?i)\b(api[_-]?key|token|password)\s*[:=]\s*[^\s,;"'']+', '[REDACTED:SECRET]')
    return $result
}

function Get-ContentFingerprint([string]$Project, [string]$Type, [string]$Statement) {
    $parts = @($Project, $Type, $Statement) | ForEach-Object {
        ([regex]::Replace(([string]$_).Trim(), '\s+', ' ')).ToLowerInvariant()
    }
    return Get-Sha256Text ($parts -join "`n")
}

function Read-ImportState([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ schema_version = 1; updated_at = $null; sessions = @() }
    }
    $value = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
    if ($null -eq $value.sessions) { $value | Add-Member -NotePropertyName sessions -NotePropertyValue @() -Force }
    return $value
}

function Write-JsonAtomic([object]$Value, [string]$Path) {
    $parent = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = Join-Path $parent ('.tmp-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $json = $Value | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
        $null = Get-Content -Raw -Encoding UTF8 -LiteralPath $temp | ConvertFrom-Json
        if (Test-Path -LiteralPath $Path) {
            $replaceBackup = Join-Path $parent ('.replace-' + [guid]::NewGuid().ToString('N') + '.json')
            try { [System.IO.File]::Replace($temp, $Path, $replaceBackup) }
            finally { if (Test-Path -LiteralPath $replaceBackup) { Remove-Item -LiteralPath $replaceBackup -Force } }
        }
        else { Move-Item -LiteralPath $temp -Destination $Path }
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

function Get-PrivacyStatus([string]$Text) {
    if ($Text -match '\[REDACTED:' -or $Text -match '患者|病人|住院|门诊|病历|病例') { return 'required' }
    return 'cleared'
}

function Get-RunId {
    return (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
}

function Get-PropertyValue($Object, [string]$Name, [string]$Default) {
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        $value = [string]$Object.$Name
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    return $Default
}

function Invoke-Import {
    $defaultSessions = Join-Path $HOME '.codex\sessions'
    if ($Mode -eq 'Fixture' -and $SessionPath -like "$defaultSessions*") { throw 'Fixture mode cannot read real sessions' }
    if ($Mode -eq 'All' -and $env:CODEX_ALLOW_ALL_IMPORT -ne 'CONFIRMED') { throw 'All mode requires confirmation checkpoint authorization' }
    if (-not (Test-Path -LiteralPath $VaultPath -PathType Container)) { throw "Vault path does not exist: $VaultPath" }

    $runId = Get-RunId
    if ($Mode -eq 'Fixture') { $packageRoot = Join-Path (Split-Path $SessionPath -Parent) "packages\$runId" }
    else {
        $runtimeRoot = if ($env:CODEX_OBSIDIAN_RUNTIME) { $env:CODEX_OBSIDIAN_RUNTIME } else { Join-Path $env:TEMP 'CodexObsidianKnowledge' }
        $packageRoot = Join-Path $runtimeRoot "packages\$runId"
    }
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    $statePath = Join-Path $VaultPath '90_System\Memory\Import-State.json'
    $indexPath = Join-Path $VaultPath '90_System\Memory\Content-Index.json'
    $reviewDir = Join-Path $VaultPath '00_Inbox\Codex-Auto-Capture\Review'
    $conflictDir = Join-Path $VaultPath '00_Inbox\Codex-Auto-Capture\Conflicts'
    $logDir = Join-Path $VaultPath '90_System\Memory\Run-Logs'
    @($reviewDir, $conflictDir, $logDir) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

    $state = Read-ImportState $statePath
    if (Test-Path -LiteralPath $indexPath) { $index = Get-Content -Raw -Encoding UTF8 -LiteralPath $indexPath | ConvertFrom-Json }
    else { $index = [pscustomobject]@{ schema_version = 1; updated_at = $null; entries = @() } }
    if ($null -eq $index.entries) { $index | Add-Member -NotePropertyName entries -NotePropertyValue @() -Force }

    $knownHashes = @{}; foreach ($item in @($state.sessions)) { $knownHashes[[string]$item.source_sha256] = $true }
    $knownFingerprints = @{}; foreach ($item in @($index.entries)) { $knownFingerprints[[string]$item.content_fingerprint] = $true }
    $topics = @{}; foreach ($item in @($index.entries)) { if ($item.topic_key) { $topics[[string]$item.topic_key] = [string]$item.content_fingerprint } }

    $inventory = @(Get-SessionInventory $SessionPath | Sort-Object LastWriteTimeUtc -Descending)
    if ($Mode -eq 'Pilot') { $inventory = @($inventory | Select-Object -First $PilotCount) }
    $created = 0; $skipped = 0; $badLines = 0; $privacyRequired = 0; $conflictCount = 0; $pendingActive = 0
    $projectCandidates = @{}

    foreach ($session in $inventory) {
        if ($Mode -eq 'All' -and $session.HashMethod -eq 'SharedReadSnapshot') {
            $existingActive = @($state.sessions | Where-Object { $_.source_session -eq $session.RelativePath })
            if ($existingActive.Count -gt 0) {
                foreach ($entry in $existingActive) {
                    $entry.status = 'pending_active'
                    if ($entry.PSObject.Properties.Name -contains 'pending_detected_at') { $entry.pending_detected_at = [datetime]::UtcNow.ToString('o') }
                    else { $entry | Add-Member -NotePropertyName pending_detected_at -NotePropertyValue ([datetime]::UtcNow.ToString('o')) }
                }
            }
            else {
                $state.sessions = @($state.sessions) + [pscustomobject]@{
                    source_session = $session.RelativePath
                    source_sha256 = $session.Sha256
                    imported_at = $null
                    run_id = $runId
                    status = 'pending_active'
                    bad_line_count = 0
                    pending_detected_at = [datetime]::UtcNow.ToString('o')
                }
            }
            $pendingActive++; $skipped++; continue
        }
        if ($knownHashes.ContainsKey($session.Sha256)) { $skipped++; continue }
        $records = @(Read-JsonlSafe $session.FullName)
        $badLines += @($records | Where-Object { -not $_.ok }).Count
        $objects = @($records | Where-Object { $_.ok } | ForEach-Object { $_.value })
        $serialized = ($objects | ConvertTo-Json -Depth 8 -Compress)
        $redacted = Get-RedactedText $serialized
        $privacy = Get-PrivacyStatus $redacted
        if ($privacy -eq 'required') { $privacyRequired++ }
        $package = [pscustomobject]@{
            run_id = $runId
            source_session = $session.RelativePath
            source_sha256 = $session.Sha256
            privacy_status = $privacy
            redacted_text = $redacted
            parse_errors = @($records | Where-Object { -not $_.ok } | ForEach-Object {
                [pscustomobject]@{ line_number = $_.line_number; error_type = $_.error_type }
            })
        }
        Write-JsonAtomic $package (Join-Path $packageRoot ($session.Sha256 + '.json'))

        $candidate = $objects | Where-Object { $_.PSObject.Properties.Name -contains 'statement' } | Select-Object -First 1
        $project = Get-PropertyValue $candidate 'project' 'Unclassified'
        $type = Get-PropertyValue $candidate 'type' 'session-summary'
        $statement = Get-PropertyValue $candidate 'statement' ("Session " + $session.Sha256.Substring(0, 12))
        $fingerprint = Get-ContentFingerprint $project $type $statement
        if (-not $projectCandidates.ContainsKey($project)) { $projectCandidates[$project] = 0 }
        $projectCandidates[$project]++
        $topicKey = Get-ContentFingerprint $project $type ''
        $conflictStatus = 'clear'
        if ($topics.ContainsKey($topicKey) -and $topics[$topicKey] -ne $fingerprint) { $conflictStatus = 'unresolved'; $conflictCount++ }
        elseif (-not $topics.ContainsKey($topicKey)) { $topics[$topicKey] = $fingerprint }

        if ($knownFingerprints.ContainsKey($fingerprint)) { $skipped++; $knownHashes[$session.Sha256] = $true; continue }
        $date = ([datetime]$session.LastWriteTimeUtc).ToString('yyyyMMdd')
        $id = 'session-' + $session.Sha256.Substring(0, 12)
        $reviewPath = Join-Path $reviewDir ("$date-$id.md")
        $note = @(
            '---',
            "id: $id",
            "source_session: $($session.RelativePath.Replace('\', '/'))",
            "source_sha256: $($session.Sha256)",
            "source_started_at: null",
            "source_ended_at: $($session.LastWriteTimeUtc)",
            "imported_at: $([datetime]::UtcNow.ToString('o'))",
            "proposed_project: $project",
            "content_types: [$type]",
            "privacy_status: $privacy",
            "conflict_status: $conflictStatus",
            'approval_status: review',
            "content_fingerprint: $fingerprint",
            '---', '', '# 会话摘要', '',
            '## 用户目标', '', '需要根据脱敏处理结果进行人工复核。', '',
            '## 当前状态', '', '本条目仅进入 Review，尚未形成正式知识。', '',
            '## 已形成的决定', '', '尚未人工确认。', '',
            '## 证据与来源', '', "来源会话：$($session.RelativePath.Replace('\', '/'))", '',
            '## 开放问题', '', '需要确认项目归属和事实状态。', '',
            '## 下一步行动', '', '人工检查后决定批准、修改或拒绝。', '',
            '## 相关输出', '', '无自动编译输出。', '',
            '## 人工复核提示', '', $(if ($privacy -eq 'required') { '存在需要人工复核的敏感内容。' } else { '未发现规则命中，但仍需人工隐私复核。' })
        ) -join "`n"
        [System.IO.File]::WriteAllText($reviewPath, $note, [System.Text.UTF8Encoding]::new($false))

        if ($conflictStatus -eq 'unresolved') {
            $conflictPath = Join-Path $conflictDir ("$date-$id-conflict.md")
            $conflictNote = "---`nid: $id-conflict`nsource_sha256: $($session.Sha256)`nconflict_status: unresolved`napproval_status: review`n---`n`n# 冲突候选`n`n同一项目与内容类型存在不同内容指纹，等待人工判断。`n"
            [System.IO.File]::WriteAllText($conflictPath, $conflictNote, [System.Text.UTF8Encoding]::new($false))
        }

        $state.sessions = @($state.sessions) + [pscustomobject]@{ source_session = $session.RelativePath; source_sha256 = $session.Sha256; imported_at = [datetime]::UtcNow.ToString('o'); run_id = $runId; status = 'review'; bad_line_count = @($records | Where-Object { -not $_.ok }).Count }
        $index.entries = @($index.entries) + [pscustomobject]@{ content_fingerprint = $fingerprint; topic_key = $topicKey; source_sha256 = $session.Sha256; review_file = $reviewPath.Substring($VaultPath.TrimEnd('\').Length).TrimStart('\'); conflict_status = $conflictStatus }
        $knownHashes[$session.Sha256] = $true; $knownFingerprints[$fingerprint] = $true; $created++
    }

    $state.updated_at = [datetime]::UtcNow.ToString('o')
    $index.updated_at = $state.updated_at
    Write-JsonAtomic $state $statePath
    Write-JsonAtomic $index $indexPath
    $logPath = Join-Path $logDir ("fixture-$runId.md")
    if ($Mode -ne 'Fixture') { $logPath = Join-Path $logDir ("$($Mode.ToLowerInvariant())-$runId.md") }
    $candidateRows = @()
    foreach ($candidateName in @($projectCandidates.Keys | Sort-Object)) {
        $basis = if ($candidateName -eq 'Unclassified') { 'No reliable project field' } else { 'Structured session field' }
        $confidence = if ($candidateName -eq 'Unclassified') { 'low' } else { 'medium' }
        $candidateRows += "| $candidateName | pending | pending | $($projectCandidates[$candidateName]) | $basis | $confidence |"
    }
    $candidateTable = @(
        '## Project Candidates', '',
        '| Suggested directory | Chinese name | Aliases | Source sessions | Basis | Confidence |',
        '|---|---|---|---:|---|---|'
    ) + $candidateRows
    $log = @(
        "# Import Run $runId", '',
        "- mode: $Mode", "- discovered: $($inventory.Count)", "- created: $created", "- skipped: $skipped",
        "- bad_lines: $badLines", "- privacy_required: $privacyRequired", "- conflicts: $conflictCount", "- pending_active: $pendingActive", ''
    ) + $candidateTable
    $log = $log -join "`n"
    [System.IO.File]::WriteAllText($logPath, $log, [System.Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ run_id = $runId; mode = $Mode; discovered = $inventory.Count; created = $created; skipped = $skipped; bad_lines = $badLines; privacy_required = $privacyRequired; conflicts = $conflictCount; pending_active = $pendingActive; log = $logPath }
}

if ($Mode -ne 'Library') { Invoke-Import }
