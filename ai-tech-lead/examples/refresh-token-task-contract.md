# 示例：Refresh Token 重放修复

## 任务身份

- 编号：AUTH-REFRESH-001
- 角色：Implementer
- 风险：R3
- 写入负责人：auth-implementer
- 基线：`abc1234`
- worktree：`.worktrees/AUTH-REFRESH-001`

## 单一目标

使 refresh token 在首次成功兑换后立即失效；同一 token 的后续或并发重复使用必须失败。

## 已验证事实

- 入口：`src/routes/auth.ts::POST /refresh`
- 核心逻辑：`src/auth/refresh-service.ts::refresh`
- 存储：`src/auth/token-repository.ts`
- 当前实现先读取 token，再单独更新状态，存在竞态。
- 现有测试：`tests/auth/refresh-token.test.ts`

## 当前行为

同一 refresh token 在有效期内可多次成功兑换。两个并发请求可能都成功。

## 目标行为

- 第一次有效请求返回新的 access token。
- token 在同一原子操作内被消费。
- 再次使用返回 HTTP 401，错误码 `REFRESH_TOKEN_REUSED`。
- 两个并发请求最多一个成功。

## 非目标

- 不修改 access token 格式。
- 不修改登录接口响应。
- 不重构整个鉴权模块。

## 允许修改

- `src/auth/refresh-service.ts`
- `src/auth/token-repository.ts`
- `tests/auth/refresh-token.test.ts`

## 禁止修改

- 用户表结构
- 公共错误响应格式
- `package.json`
- 其他认证接口

## 不变量

- 正常登录和退出行为不变。
- 旧的未使用 refresh token 继续有效。
- 不在日志中输出 token。

## 实现约束

- 消费操作必须由数据库保证原子性。
- 禁止“先查询再更新”的非原子方案。
- 禁止以内存集合记录已使用 token。
- 不新增第三方依赖。

## 验收标准

1. 有效 token 首次兑换成功。
2. 同一 token 第二次返回 401 和 `REFRESH_TOKEN_REUSED`。
3. 两个并发请求最多一个成功。
4. 无效、过期和已撤销 token 的既有行为不变。
5. 现有 auth 回归测试通过。

## 验证命令

```text
npm run typecheck
npm run lint
npm test -- refresh-token
npm test -- auth
```

## 停止条件

- 数据层不支持原子条件更新；
- 必须改变公共错误格式；
- 基线 auth 测试已失败且无法与本次影响隔离；
- 需要修改允许范围外文件。

出现任一项返回 `BLOCKED`。
