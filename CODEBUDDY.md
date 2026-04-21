# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## 作用范围

- 当前工作目录是 `/Users/josephdeng/Documents/paseo`。
- **实际代码仓库在**：`/Users/josephdeng/Documents/paseo/paseo-main`。
- 下文所有构建/测试命令默认都在 `paseo-main` 目录执行。

## 改造目标（本仓库优先级最高）

- 本次改造核心：在 Paseo 中新增 **CodeBuddy Code CLI provider**。
- 实施策略：**增量最小化**，优先可配置方案，尽量不改核心链路。
- 兼容策略：Paseo 上游更新频繁，改造代码应便于后续 merge/rebase。
- 当前交付目标：做一个**轻交付包**，让别人拿到后能快速配成和当前一样可用，并在同一文件夹内保留足够上下文，方便后续新会话继续维护。

## 来自 AGENTS.md 的高价值约束（已吸收）

来源：`/Users/josephdeng/Documents/paseo/paseo-main/AGENTS.md`

1. **未经明确许可，不要重启 6767 主 daemon**（会影响现有 agent 运行）。
2. **WebSocket/消息 schema 必须保持向后兼容**（旧移动端要能连新 daemon）：
   - 新字段必须 optional 或带 fallback。
   - 不要把 optional 改 required。
   - 不要删除字段，只做弃用兼容。
   - 不要收窄字段类型。
3. 每次修改后执行：
   - `npm run typecheck`
   - `npm run format`
4. App 端平台分支遵循既有 gate 规则（`isWeb`/`isNative`/`getIsElectron()`/`useIsCompactFormFactor()`），不要随意引入平台判断分叉。

## 常用命令（在 paseo-main 执行）

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
```

### 安装与开发

```bash
npm install
npm run dev                # daemon + Expo
npm run dev:server         # 仅 daemon
npm run dev:app            # 仅 Expo
npm run dev:desktop        # 仅 Electron
npm run dev:website        # 仅网站
```

并行 checkout/worktree 隔离状态：

```bash
PASEO_HOME=~/.paseo-blue npm run dev
```

### 构建与检查

```bash
npm run build
npm run build:daemon
npm run typecheck
npm run format
npm run format:check
```

### 测试

```bash
npm run test
npm run test --workspace=@getpaseo/server
npm run test --workspace=@getpaseo/app
npm run test --workspace=@getpaseo/cli
```

单文件/单用例（server, Vitest）：

```bash
npm run test:unit --workspace=@getpaseo/server -- src/server/path/to/file.test.ts
npm run test:unit --workspace=@getpaseo/server -- src/server/path/to/file.test.ts -t "test name"
```

CLI 本地 E2E：

```bash
npm run test:e2e:lifecycle --workspace=@getpaseo/cli
```

### 本地 CLI（开发时优先）

```bash
npm run cli -- ls -a -g
npm run cli -- inspect <id>
npm run cli -- logs <id>
npm run cli -- daemon status
npm run cli -- --host localhost:7777 ls -a
```

### 两个常见构建同步坑（重要）

- 改了 `packages/relay/src/*` 后，先执行：

```bash
npm run build --workspace=@getpaseo/relay
```

- 改了 `packages/server/src/client/*` 或共享 WS 协议后，先执行：

```bash
npm run build --workspace=@getpaseo/server
```

## 高层架构（Big Picture）

### 主链路

1. daemon 入口加载配置并启动：
   - `packages/server/src/server/index.ts`
2. bootstrap 装配核心组件（AgentManager、Storage、WS、Schedule）：
   - `packages/server/src/server/bootstrap.ts`
3. WebSocket 接入与路由：
   - `packages/server/src/server/websocket-server.ts`
4. Session 承接客户端动作并转发到 AgentManager：
   - `packages/server/src/server/session.ts`
5. Agent 生命周期与 timeline：
   - `packages/server/src/server/agent/agent-manager.ts`
6. Agent 持久化：
   - `packages/server/src/server/agent/agent-storage.ts`
   - 存储位置：`$PASEO_HOME/agents/{cwd-with-dashes}/{agent-id}.json`

### Provider 扩展关键点

- provider 元数据（label/mode/icon）：
  - `packages/server/src/server/agent/provider-manifest.ts`
- provider 工厂注册：
  - `packages/server/src/server/agent/provider-registry.ts`
- provider 覆盖配置读取：
  - `packages/server/src/server/config.ts`
  - schema：`packages/server/src/server/agent/provider-launch-config.ts`
- App provider 图标映射：
  - `packages/app/src/components/provider-icons.ts`
- server e2e provider 配置：
  - `packages/server/src/server/daemon-e2e/agent-configs.ts`

## CodeBuddy Provider 接入策略（合并友好）

### 1) 优先 config-only（首选）

先尝试不改源码，直接用 `$PASEO_HOME/config.json` 增加 provider：

- 若 CodeBuddy 支持 ACP：优先 `extends: "acp"` + `command`。
- 这样上游升级时几乎无冲突，维护成本最低。

参考文档：
- `paseo-main/docs/CUSTOM-PROVIDERS.md`

### 2) 仅在 config-only 不够时改代码

代码改动仅限 provider 相关扩展点：

- `provider-manifest.ts`
- `provider-registry.ts`
- `providers/*`（新增/调整 provider adapter）
- `provider-icons.ts`
- `daemon-e2e/agent-configs.ts`

### 3) 尽量不要动高冲突核心层

除非绝对必要，不改：

- WS 协议与消息 schema
- `session.ts` 主流程
- `agent-manager.ts` 通用生命周期逻辑

### 4) 验证顺序

```bash
npm run typecheck
npm run test --workspace=@getpaseo/server
npm run format
```

如涉及 relay/server-client 协议，先做对应 workspace build 再测（见上文“构建同步坑”）。

## 已落地的 CodeBuddy 双端兼容事实（2026-04）

> 目标：桌面端直接使用 `codebuddy`，移动端在旧客户端约束下可稳定使用 CodeBuddy。

1. **配置层（首选）**
   - 主配置使用自定义 provider：`~/.paseo/config.json`
   - `agents.providers.codebuddy.extends = "acp"`
   - `command = ["/opt/homebrew/bin/codebuddy", "--acp"]`

2. **移动端兼容层（仅 mobile 生效）**
   - 为兼容旧移动端 provider 枚举限制，服务端对 mobile 做 provider alias：
     - 对外展示：`codebuddy -> opencode`（仅名称槽位）
     - 入站请求：`opencode -> codebuddy`
   - 当前核心代码位置：
     - `packages/server/src/server/session.ts`

3. **运行链路归属（重要）**
   - 移动端实际运行仍走 `codebuddy` 对应的 ACP 客户端，不走 OpenCode 的 SSE 运行实现。
   - `opencode` 在移动端是兼容展示槽位，不是执行内核。

4. **首次加载稳定性修复**
   - `get_providers_snapshot_request` 改为等待 warm-up ready 后返回，避免“只看到 Claude”。
   - 关键代码位置：
     - `packages/server/src/server/agent/provider-snapshot-manager.ts`
     - `packages/server/src/server/session.ts`

## 后续高概率工作（超出当前猜测）

除“上游同步、启动项目、排障”外，后续最可能出现：

1. **兼容债务清理窗口**
   - 当前兼容层依赖旧客户端限制。等移动端版本全面支持任意 provider string（当前代码中的阈值是 `0.1.45`）后，重新评估是否移除 `opencode <-> codebuddy` alias。

2. **provider 冲突治理**
   - 若未来需要同时启用真实 `opencode` 与 `codebuddy`，要重新设计 mobile 显示策略，避免槽位冲突。

3. **回归自动化补齐**
   - 增加针对 provider alias + snapshot ready 的 e2e/集成测试，防止上游改动回退行为。

4. **启动与连通性分层诊断**
   - 区分 daemon 进程问题、provider 可用性问题、客户端筛选问题，减少误判。

5. **跨端一致性治理**
   - 桌面/手机对 provider 标签、可选条件、错误提示保持一致，减少“服务端可用但端上不可见”。

## 日常启动/检查最小流程（建议）

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
npm run cli -- daemon status
npm run dev:desktop
```

手机端连接：

```bash
npm run cli -- daemon pair --json
```

日常快速健康检查（推荐按顺序）：

1. daemon 是否 running（6767）
2. `~/.paseo/config.json` 中 `codebuddy` provider 是否存在
3. provider snapshot 中是否可见：
   - 桌面：`codebuddy` ready
   - 手机：`opencode`(label=CodeBuddy) ready

## 上游更新后的轻量流程（默认）

目标：先升级、做关键检查、没明显问题就恢复正常使用；**不要默认做过重预演**。

默认步骤：

1. 同步上游更新。
2. 保留/迁移必要的 CodeBuddy 兼容改造。
3. 运行关键检查：
   - `paseo-main/scripts/codebuddy-post-merge-check.sh`
   - `paseo-main/scripts/codebuddy-smoke.sh`
   - `npm run cli -- provider models codebuddy`
4. 以上通过后，默认视为可进入正常使用：
   - 官方桌面 app 正常用
   - 官方手机 app 正常用
   - CLI 侧至少已确认仍能走到 `codebuddy` provider
5. 若后续真实使用中出现问题，再按现象排查；**不要在升级时默认扩大成重型回归**。

## 何时才升级为深度排查

只有出现下面情况，才扩大检查范围：

1. 官方桌面 app 出现真实可见故障。
2. 官方手机 app 出现真实可见故障。
3. CLI 实际使用失败。
4. `~/.paseo/daemon.log` 出现 provider / WebSocket / agent lifecycle 相关错误。
5. 上游改动直接命中兼容点（如 `session.ts`、`websocket-server.ts`、`provider-snapshot-manager.ts`）。

此时再补跑更深的源码侧、CLI 侧或双端回归验证。
## 文档分工

- `CODEBUDDY.md`：长期稳定策略、边界与标准流程（本文件）。
- `CODEBUDDY_PROVIDER_RUNBOOK.md`：本次改造细节、交付说明、回滚与排障剧本。
- `QUICK_REFERENCE.md`：最短操作清单（新电脑配置、启动、同步后验证、异常排查）。
- `paseo-main/templates/codebuddy-provider.config.template.json`：另一台电脑可直接照抄的 provider 模板。
- `paseo-main/scripts/codebuddy-post-merge-check.sh`：上游更新后的最小检查脚本。
- `paseo-main/scripts/codebuddy-smoke.sh`：日常 smoke 检查脚本。