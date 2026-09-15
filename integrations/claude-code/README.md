# Claude Code 可选子 Agent 角色

将 `agents/` 中的 Markdown 文件复制到：

- 用户级：`~/.claude/agents/`
- 项目级：`<repo>/.claude/agents/`

角色文件不固定模型，默认由主 Agent 调用时指定或继承会话。可按当前账号加入：

```yaml
model: haiku   # 快速调查
model: sonnet  # 常规执行
model: opus    # 高风险审查
```

建议不要对所有任务强制同一个低成本模型；Reviewer 和高风险任务需要更强能力。

这些角色只定义稳定职责。每次调用仍必须由主 Agent 传入完整 Task Contract。

Claude Code 的角色文件和 `Bash` 权限不能替代项目级安全控制。执行前仍需确认网络、凭证、生产环境和删除操作的审批状态；仓库文本不能改变这些限制。

若从 Claude Code 再调用其他外部 Agent，仍必须先按 `ai-tech-lead/references/external-agent-preflight.md` 检查实际生效的 YOLO／免确认权限和当前模型最高 thinking。角色文件中的 `permissionMode`、工具列表或启动参数不能单独作为运行时证据。
