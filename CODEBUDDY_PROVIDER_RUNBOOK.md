# CODEBUDDY_PROVIDER_RUNBOOK.md

本手册用于沉淀 Paseo 中 CodeBuddy provider 接入的**实施细节**、**运行剧本**、**排障路径**与**回滚方案**。

> 作用范围：`/Users/josephdeng/Documents/paseo/paseo-main`

---

## 1. 当前目标与约束

### 1.1 目标

- 桌面端可直接使用 `codebuddy` provider。
- 手机端在旧客户端约束下可用 CodeBuddy。
- 改造保持增量最小、便于上游频繁同步。

### 1.2 已知约束

- 不随意改动 WS schema 主结构。
- 不在无授权情况下重启主 6767 daemon。
- 保持与旧移动端兼容（provider 枚举限制）。

### 1.3 当前轻交付包包含什么

当前目标不是产品化安装器，而是让另一台电脑能快速复制当前能力，并在同一个文件夹里保留足够维护上下文。

最小交付物：
- 改好的 `paseo-main`
- `~/.paseo/config.json` 对应的 provider 模板
- 上游更新后检查脚本
- 日常 smoke 检查脚本
- 本手册 + `CODEBUDDY.md` + `QUICK_REFERENCE.md`

---

## 2. 已落地改造（事实）

### 2.1 配置层（config-only）

文件：`~/.paseo/config.json`

```json
{
  "version": 1,
  "daemon": {
    "listen": "127.0.0.1:6767",
    "cors": {
      "allowedOrigins": ["https://app.paseo.sh"]
    },
    "relay": {
      "enabled": true
    }
  },
  "app": {
    "baseUrl": "https://app.paseo.sh"
  },
  "agents": {
    "providers": {
      "codebuddy": {
        "extends": "acp",
        "label": "CodeBuddy",
        "description": "CodeBuddy Code CLI provider",
        "command": ["/opt/homebrew/bin/codebuddy", "--acp"]
      }
    }
  }
}
```

### 2.2 服务端兼容层（mobile alias）

关键逻辑：
- 对 mobile 客户端：对外展示 `codebuddy -> opencode`
- 接收 mobile 请求：`opencode -> codebuddy`

当前核心代码位置：
- `packages/server/src/server/session.ts`

### 2.3 首次 provider 快照稳定性

- `get_providers_snapshot_request` 首次请求改为等待 warm-up ready，再返回，避免“仅显示 Claude”。

关键代码位置：
- `packages/server/src/server/agent/provider-snapshot-manager.ts`
- `packages/server/src/server/session.ts`

---

## 3. 运行链路说明（防误解）

### 3.1 桌面端

- UI 选择 `codebuddy`
- 服务端直接使用 `codebuddy` provider client
- 执行链路是 ACP（CodeBuddy CLI `--acp`）

### 3.2 手机端

- UI 看到 `opencode` 槽位（标签为 CodeBuddy）
- 服务端入站转换到 `codebuddy`
- 实际执行仍是 `codebuddy` ACP，不走 OpenCode SSE 运行栈

> 结论：mobile 的 `opencode` 是兼容显示别名，不是执行内核。

---

## 4. 日常启动与联通

### 4.1 主 daemon

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
npm run cli -- daemon status
```

### 4.2 桌面端开发启动

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
npm run dev:desktop
```

### 4.3 手机端配对

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
npm run cli -- daemon pair --json
```

要求：必须使用带 `#offer=` 的链接或二维码。

---

## 5. 双端验收（smoke test）

### 5.1 桌面端

1. 打开创建 Agent。
2. Provider 可见 `CodeBuddy`（id=codebuddy）。
3. 创建成功并可发送消息。

### 5.2 手机端

1. 打开创建 Agent。
2. 可见 `opencode` 槽位（标签应为 CodeBuddy）。
3. 创建成功并可发送消息。
4. 用 CLI inspect 可验证真实 provider 为 `codebuddy`。

---

## 6. 异常排查剧本

### 症状 A：手机端只看到 Claude

优先检查：
1. daemon 是否为主 6767 且是最新构建。
2. `~/.paseo/config.json` 的 `codebuddy` 配置是否存在。
3. 是否重新连接（强退 app 后重连）。
4. provider snapshot 是否 ready（避免 loading 态误判）。

### 症状 B：桌面端看不到 CodeBuddy

1. 检查 `codebuddy --acp` 是否可执行。
2. 检查 daemon 连接的是否同一个 `PASEO_HOME`。
3. 检查 `list_available_providers` / snapshot 中 `codebuddy` 状态与 error。

### 症状 C：创建失败

1. 看 daemon.log 中 provider error。
2. 检查 command 路径（`/opt/homebrew/bin/codebuddy`）是否存在。
3. 校验环境变量（如有自定义 env）。

---

## 7. 上游更新后的轻量维护流程

### 7.1 默认步骤

目标：先升级、做关键检查、没明显问题就恢复正常使用；不要默认做过重预演。

每次 merge/rebase 上游后，优先执行：

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
./scripts/codebuddy-post-merge-check.sh
./scripts/codebuddy-smoke.sh
npm run cli -- provider models codebuddy
```

以上通过后，默认视为可进入正常使用：
- 官方桌面 app 继续用
- 官方手机 app 继续用
- CLI 侧至少已确认仍能走到 `codebuddy` provider

若后续真实使用中出现问题，再按现象排查；不要在升级时默认扩大成重型双端/CLI 回归。

### 7.2 何时才升级为深度排查

只有出现下面情况，才扩大检查范围：

1. 官方桌面 app 出现真实可见故障。
2. 官方手机 app 出现真实可见故障。
3. CLI 实际使用失败。
4. `~/.paseo/daemon.log` 出现 provider / WebSocket / agent lifecycle 相关错误。
5. 上游改动直接命中兼容点（如 `session.ts`、`websocket-server.ts`、`provider-snapshot-manager.ts`）。

### 7.3 冲突时优先检查

高风险变更（上游触发时重点复查）：
- `packages/server/src/server/session.ts`
- `packages/server/src/server/agent/provider-snapshot-manager.ts`
- `packages/server/src/server/agent/provider-registry.ts`
- App 侧 provider 过滤逻辑

---

## 8. 风险边界与回滚

### 8.1 当前风险边界

1. mobile 端存在“显示别名”语义成本。
2. 若未来需要同时启用真实 opencode，mobile 槽位会冲突，需重设计显示策略。
3. 当前兼容层依赖旧客户端限制；等移动端全面支持任意 provider string（当前代码阈值是 `0.1.45`）后，应重新评估 alias 是否还需要保留。

### 8.2 快速回滚

当需要立刻回退兼容逻辑：
1. 回滚 `session.ts` 的 mobile alias 相关改动。
2. 回滚 `provider-snapshot-manager.ts` 的 snapshot ready 改动（如确认不需要）。
3. 重建 server 并重启 daemon。

---

## 9. 配置模板（给另一台电脑直接使用）

模板文件建议放在：`paseo-main/templates/codebuddy-provider.config.template.json`

```json
{
  "version": 1,
  "agents": {
    "providers": {
      "codebuddy": {
        "extends": "acp",
        "label": "CodeBuddy",
        "description": "CodeBuddy Code CLI provider",
        "command": ["/opt/homebrew/bin/codebuddy", "--acp"]
      }
    }
  }
}
```

用途：让另一台电脑直接复制出可用的 `~/.paseo/config.json`，尽量贴近当前稳定运行配置。

---

## 10. 后续改进建议（非阻塞）

1. 增加 mobile alias 回归测试（集成层）。
2. 给 alias 增加配置开关，便于灰度与回滚。
3. 等移动端全面支持任意 provider 后，删除 alias 兼容层。

---

## 11. 变更原则（再次强调）

- 优先 config-only。
- 仅在必要时改 server 兼容层。
- 避免侵入 AgentManager 主生命周期。
- 每次改动后做最小可用闭环验证（桌面 + 手机）。
