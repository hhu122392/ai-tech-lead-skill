# Delegation Plan

- 主任务：
- 主 Agent：
- 风险等级：
- 基线 commit：
- 最终验收负责人：主 Agent
- Git／非 Git：
- 用户已有改动快照：
- 默认隔离方式：独立 worktree / 快照目录
- R3 人工批准记录：
- 外部 Agent 前置检查记录：`references/external-agent-preflight.md`

| Task ID | 单一结果 | Agent ID／角色 | Provider／版本 | 模型／权限 | YOLO 证据 | 最高／生效 thinking | 依赖 | 唯一写入范围 | 风险 | 验收项 | 尝试 | 状态 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T-01 |  | Explorer |  | 快速／低成本 |  |  | 无 | 只读 |  |  |  | PENDING |
| T-02 |  | Implementer |  | 中等 |  |  | T-01 |  |  |  |  | PENDING |
| T-03 |  | Test Engineer |  | 中等／不同模型 |  |  | T-02 | 测试范围 |  |  |  | PENDING |
| T-04 |  | Reviewer |  | 强／不同模型 |  |  | T-02,T-03 | 只读 |  |  |  | PENDING |

状态只能使用：`PENDING`、`RUNNING`、`DONE`、`PARTIAL`、`BLOCKED`、`REJECTED`、`INTEGRATED`、`CANCELLED`、`TIMED_OUT`。

## 依赖与并行说明

- 可并行任务：
- 必须串行任务：
- 共享文件冲突处理：
- worktree／分支策略：
- 超时、崩溃和重试处理：
- 任务证据存放位置：

## 主 Agent 保留事项

- 技术决策：
- 公共接口／数据契约：
- 高风险核心实现：
- 最终测试与签字：
