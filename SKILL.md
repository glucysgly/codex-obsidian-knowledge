---
name: codex-obsidian-knowledge
description: Use when importing completed Codex sessions into an Obsidian knowledge vault, reviewing redacted session summaries, compiling approved knowledge, or installing a local six-hour Windows maintenance task.
---

# Codex Obsidian Knowledge

Use the scripts in this repository. Treat Codex JSONL as read-only. Import only creates redacted Review notes; active sessions remain pending.

Before a substantive task, read the workspace map and only the relevant approved project files. Do not treat Review, privacy-required notes, hypotheses, or unresolved conflicts as confirmed memory.

Run `install.ps1` once. Use `Run-KnowledgeMaintenance.ps1` for local import, then review notes before changing approval status. Use `Compile-Knowledge.ps1 -DryRun` before `-Apply`.

Never store patient identifiers, credentials, API keys, private links, or unredacted transcripts. Do not move, rename, or delete source JSONL.
