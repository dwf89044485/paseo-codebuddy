# REFORK_FROM_OFFICIAL.md

> 用途：当你决定**重新 fork 官方 Paseo 源码**，并在新 fork 上重新接入 CodeBuddy 时，按这份文档做。  
> 目标：最小化改动，把 CodeBuddy 重新作为 runtime 接进 Paseo，并保留桌面端 / 手机端 / CLI 的可用路径。

## 1. 先说最终思路

不要再做“外层仓库 + 里面套一个官方仓库”的结构。

**推荐结构：**
- 直接 fork 官方 `getpaseo/paseo`
- 把 CodeBuddy 相关文档、脚本、模板放进这个 fork 根目录
- 把必要的兼容代码补到官方源码里

这样以后：
- clone 只有一个仓库
- 跟官方 upstream 同步最顺
- 后续维护最收敛

---

## 2. CodeBuddy 是怎么接进去的

本次接入的核心不是“拿 OpenCode 代跑 CodeBuddy”，而是：

1. 在 `~/.paseo/config.json` 里把 `codebuddy` 注册成 **custom ACP provider**
2. 服务端读取配置后，用 `GenericACPAgentClient` 启动：
   - `codebuddy --acp`
3. 手机端为了兼容旧客户端，只在显示层把 `codebuddy` 显示成 `opencode`
4. 请求进入服务端后，又映回 `codebuddy`
5. **实际 runtime 仍然是 CodeBuddy ACP，不是 OpenCode SSE**

---

## 3. 重新 fork 官方源码时，最少要带哪些东西

### 3.1 根目录文档（建议一起带）

从当前这套仓库带过去：

- `00_START_HERE.md`
- `CODEBUDDY.md`
- `QUICK_REFERENCE.md`
- `CODEBUDDY_PROVIDER_RUNBOOK.md`
- 本文档 `REFORK_FROM_OFFICIAL.md`

这些是维护上下文，不影响运行，但能保证以后新会话不丢上下文。

### 3.2 必带文件（运行相关）

- `templates/codebuddy-provider.config.template.json`
- `scripts/codebuddy-post-merge-check.sh`
- `scripts/codebuddy-smoke.sh`

### 3.3 必带代码改动（真正 runtime 相关）

只保留下面 3 处：

1. `packages/server/src/server/session.ts`
   - 作用：手机端 `codebuddy <-> opencode` 兼容别名
2. `packages/server/src/server/agent/provider-snapshot-manager.ts`
   - 作用：provider snapshot 首次返回前等待 ready，避免只看到 Claude
3. `packages/server/src/server/websocket-server.ts`
   - 作用：把 `clientType` 透传给 session，让 alias 只对 mobile 生效

**重点：** 如果你重新 fork 官方源码，真正必须重做的就是这 3 个代码点 + 模板/脚本。

---

## 4. 关键代码定位（重新补丁时直接看这里）

### 4.1 自定义 ACP provider 配置入口

- `packages/server/src/server/persisted-config.ts:121`
- `packages/server/src/server/persisted-config.ts:164`
- `packages/server/src/server/config.ts:56`
- `packages/server/src/server/config.ts:170`

说明：
- 这里负责接收 `agents.providers.codebuddy`
- `extends: "acp"` + `command` 是合法路径

### 4.2 服务端把 CodeBuddy 真正建成 runtime client

- `packages/server/src/server/agent/provider-registry.ts:400`
- `packages/server/src/server/agent/provider-registry.ts:421`
- `packages/server/src/server/bootstrap.ts:423`
- `packages/server/src/server/bootstrap.ts:436`

说明：
- 这里会把 `codebuddy` 作为 custom ACP provider 建成 `GenericACPAgentClient`
- 真正执行的是 `codebuddy --acp`

### 4.3 手机端 alias 兼容

- `packages/server/src/server/session.ts:229`
- `packages/server/src/server/session.ts:235`
- `packages/server/src/server/session.ts:236`
- `packages/server/src/server/session.ts:1228`
- `packages/server/src/server/session.ts:1235`
- `packages/server/src/server/session.ts:1242`
- `packages/server/src/server/session.ts:1279`
- `packages/server/src/server/session.ts:1298`

说明：
- mobile 端显示 `opencode`
- 服务端内部仍回到 `codebuddy`

### 4.4 provider 首次 ready 稳定性

- `packages/server/src/server/agent/provider-snapshot-manager.ts:40`
- `packages/server/src/server/agent/provider-snapshot-manager.ts:54`
- `packages/server/src/server/agent/provider-snapshot-manager.ts:120`

说明：
- 关键是 `getSnapshotReady()`
- 避免 provider warm-up 没完成时 UI 只显示 Claude

### 4.5 clientType 透传

- `packages/server/src/server/websocket-server.ts:879`
- `packages/server/src/server/websocket-server.ts:881`
- `packages/server/src/server/session.ts:874`

说明：
- 只让 mobile 吃 alias，避免污染 browser / CLI

---

## 5. 从官方重新 fork 的建议步骤

### 第 1 步：fork 官方 repo

目标仓库直接 fork：
- 上游：`getpaseo/paseo`
- 你的仓库：例如 `yourname/paseo-codebuddy`

### 第 2 步：clone 你的 fork

```bash
git clone https://github.com/<you>/paseo-codebuddy.git
cd paseo-codebuddy
```

### 第 3 步：先把文档 / 模板 / 脚本放进去

至少补这些：

- `00_START_HERE.md`
- `CODEBUDDY.md`
- `QUICK_REFERENCE.md`
- `CODEBUDDY_PROVIDER_RUNBOOK.md`
- `REFORK_FROM_OFFICIAL.md`
- `templates/codebuddy-provider.config.template.json`
- `scripts/codebuddy-post-merge-check.sh`
- `scripts/codebuddy-smoke.sh`

### 第 4 步：补 3 处服务端兼容代码

按第 4 节给出的定位，把最小兼容补丁补回去：

1. `session.ts`
2. `provider-snapshot-manager.ts`
3. `websocket-server.ts`

**原则：**
- 只补 CodeBuddy 接入必须的最小改动
- 不顺手做别的重构
- 不把无关本地差异一起带过去

### 第 5 步：提交到你的 fork

```bash
git add .
git commit -m "feat: add codebuddy runtime integration"
git push origin main
```

---

## 6. 新机器首次部署怎么做

clone 下来后，在仓库根目录：

```bash
mkdir -p ~/.paseo
cp ./templates/codebuddy-provider.config.template.json ~/.paseo/config.json
npm install
```

如果当前机器 `codebuddy` 不在模板默认路径，就把：

- `templates/codebuddy-provider.config.template.json`
- `~/.paseo/config.json`

里的 command 改成当前机器真实路径，例如：

```json
"command": ["/usr/local/bin/codebuddy", "--acp"]
```

---

## 7. 启动与手机配对

启动 daemon：

```bash
npm run dev:server
```

另开一个终端：

```bash
npm run cli -- daemon pair --json
```

要求：
- 手机端配对链接必须带 `#offer=`
- 手机端看到 `opencode`（标签 CodeBuddy）是正常的

---

## 8. 轻量验证（默认）

不要一上来做很重的回归。默认只做：

```bash
./scripts/codebuddy-post-merge-check.sh
./scripts/codebuddy-smoke.sh
npm run cli -- provider models codebuddy
```

通过后就先正常使用。
有真实故障，再扩大排查。

---

## 9. 以后上游再更新时怎么维护

以后你说“更新”，默认流程就是：

1. 拉官方 upstream 新版本
2. 看第 4 节那 3 个关键代码点有没有被冲掉
3. 跑轻量检查
4. 没问题就继续用
5. 有问题再按现象排查

**不要默认每次都做重型回归。**

---

## 10. 最后一句判断标准

如果一个新 fork 满足下面 4 条，就说明 CodeBuddy runtime 已经重新接好：

1. `~/.paseo/config.json` 里有 `codebuddy` ACP provider
2. `provider models codebuddy` 能成功
3. 桌面端能看到 `codebuddy`
4. 手机端能看到 `opencode` 槽位（标签 CodeBuddy），且实际执行仍是 CodeBuddy
