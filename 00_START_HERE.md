# 00_START_HERE.md

> 这是一份给“任意新机器”用的总入口文档。  
> 目标：clone 后，最快完成 **CodeBuddy 接入 + 启动服务 + 手机配对**。

## 0) 前提

- 已在当前目录 `git clone` 本仓库（`paseo-codebuddy`）
- 机器已安装并认证 `codebuddy`
- 手机上已安装官方 Paseo app

---

## 1) 首次初始化（每台机器只做一次）

在仓库根目录执行：

```bash
mkdir -p ~/.paseo
cp ./templates/codebuddy-provider.config.template.json ~/.paseo/config.json
npm install
```

说明：
- 这一步不是官方自动做的，是部署动作的一部分。
- 之后服务重启通常不需要重做。
- 只有 `~/.paseo/config.json` 丢失/被覆盖时才需要重做。

---

## 2) 日常启动 + 手机配对（可重复执行）

### 2.1 启动 daemon

```bash
npm run dev:server
```

### 2.2 新开一个终端（同目录）生成配对信息

```bash
npm run cli -- daemon pair --json
```

用返回的链接或二维码在手机端配对。  
配对链接必须包含 `#offer=`。

---

## 3) 最小可用性检查

```bash
npm run cli -- daemon status
npm run cli -- provider models codebuddy
```

通过后就可以直接用官方桌面/手机 app。

---

## 4) 一条兜底命令（不确定是否初始化过时）

```bash
mkdir -p ~/.paseo
[ -f ~/.paseo/config.json ] || cp ./templates/codebuddy-provider.config.template.json ~/.paseo/config.json
npm run dev:server
```

然后另一个终端执行：

```bash
npm run cli -- daemon pair --json
```

---

## 5) 让 AI 直接执行（可复制）

把下面这段话直接发给 AI：

```text
在当前仓库帮我完成：
1) 如果 ~/.paseo/config.json 不存在，就从 ./templates/codebuddy-provider.config.template.json 自动复制
2) 启动 daemon（dev:server）
3) 执行 daemon pair --json，给我配对链接/二维码
4) 验证 provider models codebuddy 可用
5) 最后只告诉我“现在去手机上配对”的下一步操作
```

---

## 6) 上游更新后的轻量检查

```bash
./scripts/codebuddy-post-merge-check.sh
./scripts/codebuddy-smoke.sh
npm run cli -- provider models codebuddy
```

通过后先正常使用；有真实问题再排查。