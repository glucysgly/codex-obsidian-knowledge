# Codex Obsidian Knowledge

Privacy-first local memory workflow for Codex and Obsidian. It imports completed Codex sessions as redacted Review notes, then compiles only approved and privacy-cleared knowledge.
简介：这是一个把 Codex 聊天内容整理进 Obsidian 的“小管家”。
它会定期检查已经结束的 Codex 对话，把有用内容整理成 Obsidian 笔记；涉及手机号、邮箱、密钥或可能的患者信息会先打码。新内容先放进“待审核区”，不会直接当成长期结论。
你确认过的内容，才会被整理进正式知识库。这样以后再次打开 Codex 做项目时，它可以优先读取你已经确认的项目进展、决定和资料，不必每次从头解释。
它不会删除或改动原始聊天记录，也不会自动把敏感内容、猜测或未确认结论写进正式知识库


详细功能介绍：
codex-obsidian-knowledge 是一个独立、可本地部署的 Codex Skill，用于把 Codex 的已结束会话逐步沉淀到 Obsidian Vault，而不是把原始对话直接复制成知识库。
核心功能包括：
只读扫描 Codex JSONL 会话，不移动、修改或删除原始记录。
自动识别活跃会话并标记为 pending_active，避免导入仍在写入的内容。
对手机号、邮箱、身份证号、医疗编号、API Key 和常见凭据进行脱敏。
使用 SHA-256 去重，避免重复导入同一会话。
将内容先写入 Obsidian 的 Review 层，而非直接视为长期知识。
通过 approval_status、privacy_status 和 conflict_status 三重门禁控制知识编译。
仅将“已批准、隐私已清除、无未解决冲突”的摘要写入正式项目知识或通用知识页。
使用受管区块写入，保留用户在知识页中手工补充的内容。
提供可选的 Windows 计划任务，每 6 小时自动执行本地维护。
默认将运行时脱敏包和日志放到 D 盘，减少系统盘压力。
提供一键安装、卸载、回滚说明和 fixture 测试。
让 Codex 在新任务开始时优先读取已批准的 Obsidian 项目记忆，而不默认加载原始会话、Review 或敏感内容。
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
