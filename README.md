# Codex Obsidian Knowledge

Privacy-first local memory workflow for Codex and Obsidian. It imports completed Codex sessions as redacted Review notes, then compiles only approved and privacy-cleared knowledge.

## Install

```powershell
git clone https://github.com/glucysgly/codex-obsidian-knowledge.git
cd codex-obsidian-knowledge
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallSchedule
```

The installer asks for an Obsidian Vault and uses the local Codex sessions directory by default. Runtime packages use `D:\CodexObsidianRuntime` when D is available. The optional Windows task runs every six hours.

## Workflow

1. The scheduler reads completed JSONL sessions without modifying them.
2. It writes redacted summaries to `00_Inbox/Codex-Auto-Capture/Review`.
3. You review and approve safe notes.
4. Run `Compile-Knowledge.ps1 -DryRun`, then `-Apply` only when ready.

Active sessions are marked pending. The scheduler never approves notes, compiles knowledge, deletes source sessions, or resolves research conflicts.

## Commands

```powershell
.\scripts\Run-KnowledgeMaintenance.ps1 -VaultPath 'D:\MyVault' -SessionPath "$HOME\.codex\sessions" -RuntimePath 'D:\CodexObsidianRuntime'
.\scripts\Compile-Knowledge.ps1 -VaultPath 'D:\MyVault' -DryRun
.\uninstall.ps1 -TaskOnly
```

## Safety

Do not place patient identifiers, credentials, keys, or unredacted transcripts in approved knowledge. Review notes with `privacy_status: required` remain excluded from compilation.

Inspired by context-engineering ideas discussed publicly by Andrej Karpathy; independently designed and implemented. This project has no official affiliation, endorsement, or validation by Karpathy.
