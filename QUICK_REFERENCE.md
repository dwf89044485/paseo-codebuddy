# Paseo 值班速查表（On-call Quick Reference）

> 目的：面向**高频维护场景**（上游同步、启动、双端可用性验证、异常排查）的最短操作清单。  
> 详细背景与设计说明请看：`CODEBUDDY_PROVIDER_RUNBOOK.md`。

## 0. 关键路径

- 工作区根：`/Users/josephdeng/Documents/paseo`
- 主仓库：`/Users/josephdeng/Documents/paseo/paseo-main`
- 主配置：`~/.paseo/config.json`
- 配置模板：`/Users/josephdeng/Documents/paseo/paseo-main/templates/codebuddy-provider.config.template.json`
- 更新后检查脚本：`/Users/josephdeng/Documents/paseo/paseo-main/scripts/codebuddy-post-merge-check.sh`
- 日常 smoke 脚本：`/Users/josephdeng/Documents/paseo/paseo-main/scripts/codebuddy-smoke.sh`
- 主日志：`~/.paseo/daemon.log`

## 1. 新电脑快速配置（最短）

```bash
mkdir -p ~/.paseo
cp "/Users/josephdeng/Documents/paseo/paseo-main/templates/codebuddy-provider.config.template.json" ~/.paseo/config.json
cd "/Users/josephdeng/Documents/paseo/paseo-main"
npm install
```

然后继续下面的启动步骤。

## 2. 日常启动（最短）

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
npm run cli -- daemon status
npm run dev:desktop
```

手机配对：

```bash
npm run cli -- daemon pair --json
```

## 3. CodeBuddy 双端可用性检查

### 桌面端（browser）

- 创建 Agent 时应看到 `codebuddy`（标签 CodeBuddy）。
- 创建后可发消息。

### 手机端（mobile）

- 创建 Agent 时应看到 `opencode` 槽位（标签 CodeBuddy）。
- 这是兼容显示别名；实际运行 provider 是 `codebuddy`。

CLI 侧可核验真实 provider：

```bash
npm run cli -- inspect <agent-id>
```

应显示 `Provider: codebuddy`。

## 4. 上游同步后的轻量更新流程

默认只做关键检查，不做过重预演：

```bash
cd /Users/josephdeng/Documents/paseo/paseo-main
./scripts/codebuddy-post-merge-check.sh
./scripts/codebuddy-smoke.sh
npm run cli -- provider models codebuddy
```

以上通过后，默认就进入正常使用：

1. 官方桌面 app 直接继续用
2. 官方手机 app 直接继续用
3. CLI 侧默认认为仍可走到 `codebuddy` provider

只有真实使用中出现问题，再扩大排查范围。不要在每次更新时默认做重型双端/CLI 回归。

## 5. 常见异常快速判断

### 现象 A：手机只看到 Claude

按顺序检查：

1. `npm run cli -- daemon status` 是否是主 6767 且 running
2. `~/.paseo/config.json` 是否有 `agents.providers.codebuddy`
3. 手机是否强退重连
4. provider snapshot 是否已 ready（避免停在 loading）

### 现象 B：桌面看不到 CodeBuddy

1. `codebuddy --acp` 是否可执行
2. daemon 是否用了正确 `PASEO_HOME`（即 `~/.paseo`）
3. daemon.log 中 codebuddy provider 是否报错

## 6. 当前兼容策略（记忆点）

- mobile 端做 `opencode <-> codebuddy` 别名映射，仅为旧客户端兼容。
- 执行链路仍是 CodeBuddy ACP，不走 OpenCode SSE 运行实现。
- 首次 provider snapshot 已改为等待 ready，减少“只见 Claude”。

## 7. 文档权威分工

- `CODEBUDDY.md`：长期稳定策略、边界、标准流程。
- `CODEBUDDY_PROVIDER_RUNBOOK.md`：本次改造细节、交付说明、风险、回滚、排障剧本。
- `QUICK_REFERENCE.md`（本文件）：值班速查操作清单。
