# 启动 & 关闭小云朵（速查）

> 这个小云朵（`PromptCocoIsland`）是 macOS 原生 SwiftUI 程序，**无 Dock 图标**，启动后只在屏幕顶部刘海位置出现。
> 因为没有图标，"关掉它"必须用命令行 kill 进程。本文就是讲这个。

---

## 🚀 启动

### 方式一：直接运行（已经编译过的话最快）

```bash
/Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/build/PromptCocoIsland
```

### 方式二：npm 快捷脚本（在项目根目录执行）

```bash
cd /Users/wy770/Desktop/PromptCocoPilot
npm run claude:island
```

### 方式三：后台运行（关掉终端不会停，推荐）

```bash
nohup /Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/build/PromptCocoIsland >/tmp/pc.log 2>&1 &
```

> 前台运行（方式一/二）时，**关掉终端 = 云朵跟着退出**。想让它在后台长期跑用方式三。

### ⚠️ 启动前确保：编译过 + 增强服务在跑

1. **首次/改过代码**要先编译：
   ```bash
   bash /Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/build.sh
   ```
2. **点"优化"要用到后端**，否则会提示「增强服务未运行」：
   ```bash
   python3 /Users/wy770/Desktop/PromptCocoPilot/mcp-server/http_server.py --host 127.0.0.1 --port 8765
   ```

---

## 🔪 关闭（kill 进程）

小云朵没有界面上的关闭按钮，必须 kill 进程。

### 关掉所有小云朵实例（最常用）

```bash
pkill -9 -f PromptCocoIsland
```

> `-9` 是强制杀（SIGKILL），立即生效。如果你只有一个实例在跑，这条就够了。

### 先看一眼有几个进程在跑

```bash
pgrep -fl PromptCocoIsland
```

输出形如：
```
29707 /Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/build/PromptCocoIsland
```
左边那个数字就是 PID。

### 按 PID 精确杀（只杀指定那个）

```bash
kill -9 29707        # 把 29707 换成你实际的 PID
```

### 杀完确认已经停了

```bash
pgrep -fl PromptCocoIsland
```
**没有任何输出 = 已经全部关掉。**

---

## 🔄 重启（关掉再启动，一条龙）

```bash
pkill -9 -f PromptCocoIsland; sleep 2; nohup /Users/wy770/Desktop/PromptCocoPilot/claude-ui/swift/build/PromptCocoIsland >/tmp/pc.log 2>&1 &
```

等 2-3 秒，刘海位置的云朵就是新启动的实例了。

---

## 常见问题

| 现象 | 原因 / 解决 |
|------|------------|
| 启动后刘海没出现 | 确认进程在跑：`pgrep -fl PromptCocoIsland`，没输出就是没起来 |
| `No such file or directory` | 没编译过，先跑 `bash claude-ui/swift/build.sh` |
| 改了代码没生效 | **光重启不够**，要先重新编译（`bash build.sh`）再启动 |
| 提示「增强服务未运行」 | 先起 `mcp-server/http_server.py`（见上文） |
| 想同时开多个 | 不建议，会出现重复云朵。先 `pkill` 再启动 |
