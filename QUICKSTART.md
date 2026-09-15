# 5 分钟上手

## 1. 安装

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Scope User -Target Both
```

首次安装建议先运行 `-DryRun` 检查目标；覆盖安装使用 `-Force`，脚本会保留旧版本备份。

macOS / Linux / WSL：

```bash
chmod +x install.sh
./install.sh --scope user --target both
```

首次安装建议先运行 `--dry-run` 检查目标；覆盖安装使用 `--force`，脚本会保留旧版本备份。

## 2. 在项目中补充质量规则

把 `ai-tech-lead/assets/PROJECT_QUALITY_PROFILE_TEMPLATE.md` 复制到项目中，填写：

- 安装与启动命令
- 编译、类型检查、Lint 命令
- 定向测试、模块测试、全量测试命令
- 关键架构和禁止修改范围
- 高风险模块和回滚方式

将最终内容放进 `AGENTS.md`、`CLAUDE.md` 或项目文档中。

非 Git 项目先建立完整快照和恢复命令；没有可回滚证据时不要派写任务。

## 3. 第一次使用

```text
$ai-tech-lead
作为本任务的技术总监：
1. 先读取项目规则与真实代码，建立基线；
2. 在派工前给出验收标准；
3. 将可定义、可隔离、可验证、可回滚的编码任务交给执行 Agent；
4. 你负责审查最终 Diff、独立重跑测试并给出最终验收结论。

任务：<填写需求>
```

Claude Code 将 `$ai-tech-lead` 改为 `/ai-tech-lead`。

## 4. 判断 Skill 是否真正生效

主 Agent 应该表现为：

- 不会把原始需求原样转发给子 Agent；
- 会先调查项目、定义验收矩阵和风险等级；
- 会给子 Agent 一份包含范围、禁止项、不变量、测试和停止条件的任务合同；
- 不会只相信子 Agent 的口头总结；
- 会查看实际 Diff，并在最终集成状态下重新执行验证；

调用终端里的 Claude Code、Pi、Gemini CLI 或其他外部 Agent 前，先完成 `references/external-agent-preflight.md` 的两项检查：实际生效的 YOLO／免确认权限，以及当前模型可用的最高 thinking。任一项没有证据都必须停止调用，不要靠反复点击 `allow`。
- 不能完整验证时，会明确标记“已实现但未完全验收”，而不是宣称完成。
