# 外部 Agent 调用前置检查

这是一道调用前的硬门槛，适用于通过终端、插件、脚本或宿主接口启动的所有外部 Agent。Claude Code、Pi、Gemini CLI 只是适配示例，不是完整名单；新工具必须按同一规则取证。

## 1. 两项检查

### A. 权限／YOLO

先确认 Agent 当前**实际生效**的权限模式，而不是只看启动命令或配置文件。记录：

- Agent 和版本；
- 完整启动命令（脱敏，不记录 Token）；
- 生效的 permission mode、工具白名单和项目／工作区信任状态；
- 是否会在每次写入、命令或网络操作前弹出确认；
- 取证命令、会话状态输出或可审计日志的位置。

需要无人值守写入时，只有确认 YOLO、免确认、bypass 或等价模式已经生效，权限检查才算 `PASS`。只知道存在某个参数、环境变量或第三方扩展不算通过。没有免确认模式时，不得用人工反复点击 `allow` 代替检查，应先 `BLOCKED`，再由主 Agent 改成已批准的非交互配置或亲自处理。

YOLO 只表示减少交互确认，不扩大任务合同的范围，也不批准秘密读取、外传、生产操作、删除或权限放宽。此类操作仍需单独的人工批准、隔离环境和回滚证据。

### B. 最高 thinking

读取当前 Agent 和**当前模型**实际可用的 thinking／reasoning 等级，选择最高可用值，并在启动后再次确认生效值。记录：

- 当前模型标识；
- 支持等级的来源（`--help`、官方文档、会话命令或可审计状态）；
- 最高支持等级；
- 本次实际生效等级；
- 不支持或无法观察时的处理。

不能把 `max` 当作所有工具的通用开关，也不能用“高推理”“默认配置”证明已达到最高挡位。最高可用值或生效值无法观察时，thinking 检查为 `BLOCKED`，不得静默换模型或降级。

## 2. 通用执行顺序

1. 读取工具的当前版本和帮助信息，确认可用的权限与 thinking 参数。
2. 在目标工作区之外先做一次无副作用探针，确认权限模式和 thinking 状态确实生效；探针不得读取秘密、联网或改文件。
3. 填写下面的记录，并由主 Agent 判断是否满足任务合同、风险等级和隔离要求。
4. 两项均为 `PASS` 才能启动外部 Agent 的编码工作；任一为 `BLOCKED` 就停止调用并上报。
5. Agent 退出、超时或配置改变后，下一次调用必须重新检查，不能沿用旧证据。

## 3. 常用工具适配

### Claude Code

- 使用当前版本 `claude --help` 和 [Claude Code CLI 文档](https://docs.anthropic.com/en/docs/claude-code/cli-usage)确认 `--permission-mode` 的实际取值。`--dangerously-skip-permissions` 或生效的 `bypassPermissions` 属于高风险免确认能力，只能在已批准的隔离 worktree／容器中使用；不能因为角色文件里写了 `tools: Bash` 就认为它已生效。
- thinking／effort 的参数和可用等级随 Claude Code 与模型版本变化。以当前 CLI、会话设置和模型状态为准，记录实际生效值；本 Skill 不硬编码一个可能失效的 `--thinking max` 命令。

### Pi

- Pi [官方使用文档](https://pi.dev/docs/latest/usage)提供项目批准（`--approve`／`--no-approve`）、工具允许范围和 `--thinking <level>`；当前文档列出的 thinking 等级包含 `off`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`。调用前用当前版本帮助或 `/thinking` 确认实际生效值。
- Pi 核心不保证存在名为“YOLO”的统一模式；`yolo` 可能来自第三方 modes 扩展。因此必须用会话 `/mode`、扩展版本和实际权限状态证明该模式已启用。仅看到扩展名称或 `--approve` 不等于所有工具都免确认。

### Gemini CLI 及其他工具

- 不假设存在统一的 YOLO 或 thinking 参数。先读取当前版本的 `--help`、会话状态和官方配置说明，找出等价的免确认权限和最高推理等级。
- 若工具没有可审计的权限状态或最高 thinking 证据，按 `BLOCKED` 处理；不要用猜测的参数、交互点击或“默认应该是最高”代替证据。

## 4. 记录模板

```text
外部 Agent 前置检查
- Task ID：
- Provider／Agent／版本：
- 启动命令（已脱敏）：
- 当前模型：
- 权限模式：
- YOLO／免确认等价模式：PASS / BLOCKED / NOT_APPLICABLE
- 权限证据（命令／会话输出／日志路径）：
- 最高 thinking 等级：
- 本次生效 thinking：
- thinking 证据（命令／会话输出／文档版本）：
- 工作区隔离（worktree／容器／快照）：
- 网络、凭证、生产、删除权限：
- 检查时间：
- 主 Agent 结论：PASS / BLOCKED
```

`NOT_APPLICABLE` 只允许用于完全只读、不会启动工具调用的分析请求，并要写明理由；只要 Agent 会执行命令或写入文件，就必须证明免确认权限或返回 `BLOCKED`。
