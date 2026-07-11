param(
    [string]$VaultPath = '',
    [switch]$DryRun,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
if ($DryRun -eq $Apply) { throw 'Specify exactly one of -DryRun or -Apply' }

function Get-FrontmatterField([string]$Text, [string]$Name) {
    if ($Text -match "(?m)^$([regex]::Escape($Name)): (.+)$") { return $Matches[1].Trim() }
    return ''
}

function Get-Section([string]$Text, [string]$Heading) {
    $pattern = "(?s)## $([regex]::Escape($Heading))\r?\n\r?\n(.*?)(?=\r?\n## |\z)"
    if ($Text -match $pattern) { return $Matches[1].Trim() }
    return ''
}

function Write-Utf8Atomic([string]$Path, [string]$Text) {
    $parent = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = Join-Path $parent ('.tmp-' + [guid]::NewGuid().ToString('N') + '.md')
    try {
        [System.IO.File]::WriteAllText($temp, $Text, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temp -Destination $Path -Force
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

$reviewDir = Join-Path $VaultPath '00_Inbox\Codex-Auto-Capture\Review'
$reviewFiles = @(Get-ChildItem -LiteralPath $reviewDir -File -Filter '*.md' -ErrorAction SilentlyContinue)
$created = 0; $modified = 0; $skipped = 0; $conflicts = 0; $eligible = 0
$actions = @()

foreach ($reviewFile in $reviewFiles) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewFile.FullName
    $approval = Get-FrontmatterField $text 'approval_status'
    $privacy = Get-FrontmatterField $text 'privacy_status'
    $conflict = Get-FrontmatterField $text 'conflict_status'
    if ($approval -ne 'approved' -or $privacy -ne 'cleared' -or $conflict -eq 'unresolved') { $skipped++; continue }

    $eligible++
    $id = Get-FrontmatterField $text 'id'
    $project = Get-FrontmatterField $text 'proposed_project'
    $fingerprint = Get-FrontmatterField $text 'content_fingerprint'
    $goal = Get-Section $text '用户目标'
    $status = Get-Section $text '当前状态'
    $projectDir = Join-Path $VaultPath "10_Projects\$project"
    if (Test-Path -LiteralPath $projectDir -PathType Container) {
        $destination = Join-Path $projectDir 'Project-Status.md'
    }
    else {
        $safeName = $project -replace '[<>:"/\\|?*]', '-'
        $destination = Join-Path $VaultPath "20_Knowledge\$safeName.md"
    }

    $block = @(
        "<!-- BEGIN MANAGED:$id -->",
        "### $id", '',
        "- 来源：[[${($reviewFile.BaseName)}]]",
        "- 内容指纹：$fingerprint",
        "- 项目候选：$project", '',
        '**用户目标**', '', $goal, '',
        '**当前状态**', '', $status,
        "<!-- END MANAGED:$id -->"
    ) -join "`n"
    $begin = "<!-- BEGIN MANAGED:$id -->"
    $end = "<!-- END MANAGED:$id -->"

    if (Test-Path -LiteralPath $destination) { $destinationText = Get-Content -Raw -Encoding UTF8 -LiteralPath $destination }
    else { $destinationText = "# $project`n" }
    $existingPattern = "(?s)$([regex]::Escape($begin)).*?$([regex]::Escape($end))"
    if ($destinationText -match $existingPattern) {
        if ($Matches[0] -eq $block) { $actions += "SKIP $destination"; continue }
        $conflicts++; $actions += "CONFLICT $destination"; continue
    }

    $newText = $destinationText.TrimEnd() + "`n`n" + $block + "`n"
    if ($DryRun) { $actions += "WOULD_WRITE $destination"; continue }
    $wasPresent = Test-Path -LiteralPath $destination
    Write-Utf8Atomic $destination $newText
    if ($wasPresent) { $modified++ } else { $created++ }
    $actions += "WRITE $destination"
}

$actions | ForEach-Object { Write-Output $_ }
[pscustomobject]@{
    mode = if ($DryRun) { 'DryRun' } else { 'Apply' }
    eligible = $eligible
    created = $created
    modified = $modified
    skipped = $skipped
    conflicts = $conflicts
}
