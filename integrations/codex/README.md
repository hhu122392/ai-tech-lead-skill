# Codex 可选 Agent 角色

将 `agents/` 中的 TOML 文件复制到：

- 用户级：`~/.codex/agents/`
- 项目级：`<repo>/.codex/agents/`

这些文件不硬编码模型，默认继承主会话或调用时指定的模型，避免模型名称更新导致失效。可在每个 TOML 中加入当前环境支持的：

```toml
model = "<your-worker-model>"
model_reasoning_effort = "medium"
```

建议：

- `techlead_explorer`：快速、低成本、只读
- `techlead_implementer`：中等成本、workspace-write
- `techlead_test_engineer`：中等或不同模型、workspace-write
- `techlead_reviewer`：强模型、高推理、只读

项目 `.codex/config.toml` 可设置并发上限：

```toml
[agents]
# 这是总线程上限；Skill 仍限制同时写任务默认不超过 3 个。
max_concurrent_threads_per_session = 4
```

部分 Codex 版本还需要在配置中启用多 Agent：

```toml
[features]
multi_agent = true
```

安装角色文件不等于已经启用派工能力；以当前版本实际显示的工具和配置文档为准。

主 Agent 仍需按照 `ai-tech-lead` Skill 生成 Task Contract；角色文件不能替代具体任务上下文。

若通过终端调用 Claude Code、Pi、Gemini CLI 或其他外部 Agent，必须先完成 `ai-tech-lead/references/external-agent-preflight.md`：核实实际生效的 YOLO／免确认权限和当前模型最高／生效 thinking，并保存证据；没有证据就 `BLOCKED`。
