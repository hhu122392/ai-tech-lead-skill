# Pi 与其他外部 Agent 调用说明

本目录只提供调用约束，不会自动修改 Pi、Gemini CLI 或其他外部工具的配置。它们都必须遵守同一份前置检查：
`ai-tech-lead/references/external-agent-preflight.md`。

## 调用前必须确认

1. 用当前版本的帮助信息和会话状态确认实际生效的免确认／YOLO／bypass 等价权限模式。没有证据就停止，不要靠反复点击 `allow`。
2. 确认当前模型支持的最高 thinking／reasoning 等级，并在启动后核对本次生效值。记录最高值、生效值、证据和时间。
3. 在独立 worktree、容器或完整快照中运行；网络、凭证、生产、删除和权限放宽仍需要单独人工批准。

## Pi

Pi 官方文档列出 `--approve`／`--no-approve`、工具范围和 `--thinking <level>`；当前等级包括 `off`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`。实际调用时以 `pi --help`、`/thinking` 和会话状态为准：

```text
pi --thinking max --approve
```

上面的命令只是参数示例，不是“已经生效”的证据。必须在会话中核对实际模型、thinking 值和权限状态。

Pi 核心不保证存在统一的 `yolo` 模式。若使用第三方 modes 扩展，必须记录扩展名称、版本和 `/mode` 的实际输出；仅看到 `yolo` 字样或 `--approve` 不等于所有工具都免确认。

## Gemini CLI、Claude Code 及其他 Agent

不要照抄 Pi 的参数。先运行当前工具的 `--help`，查询当前会话／设置和模型能力，再把实际生效的权限与 thinking 记录到 Task Contract。Claude Code 的 `--dangerously-skip-permissions`／`bypassPermissions` 只能在已批准的隔离环境使用；Gemini CLI 或其他工具若没有可审计的等价模式和最高 thinking 证据，状态为 `BLOCKED`。

## 不负责的事情

- 不自动开启高风险权限，不替用户批准网络、凭证、生产或删除操作；
- 不把角色文件、插件名称或默认配置当作运行时证据；
- 不为不存在的工具参数提供静默降级或猜测性配置。

参考：

- [Pi 官方使用文档](https://pi.dev/docs/latest/usage)
- [Claude Code CLI 文档](https://docs.anthropic.com/en/docs/claude-code/cli-usage)
