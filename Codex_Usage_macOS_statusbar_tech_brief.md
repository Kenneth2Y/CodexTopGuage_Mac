# macOS 顶部状态栏 Codex Usage 实时显示小程序：技术建议与开发说明（非强制）

目标：在 macOS menu bar / status bar 中周期性显示 Codex 5小时与7天 usage、reset 时间与基础运行状态。本文档供开发者实现小程序使用

## 1. 背景与结论

在 macOS 本地发现并使用了 Codex app-server 的内部/实验性 RPC 通道：`account/rateLimits/read`。

推荐实现路径：

1. 主路径：调用 `/Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://`，发送 `initialize`，再发送 `account/rateLimits/read`。
2. fallback：读取 `~/.codex/state_5.sqlite` 里最近线程的 `rollout_path`，tail 对应 JSONL 日志，解析 `payload.type == "token_count"` 的事件。
3. UI：用原生 macOS menu bar app 做 `NSStatusItem`；每 15–60 秒轮询一次即可。
4. 风险：这不是公开稳定 API，Codex 更新后方法名、返回结构、SQLite 表结构或 rollout 日志格式可能变化。

## 2. 产品形态

- 顶部状态栏显示，例如：`Cdx 5h23% 7d41%`。（如此紧凑显示）
- 点击后显示详情：5h usage、7d usage、两者 reset 倒计时、最近 tokens、数据来源、最后更新时间。
- 默认 15 秒刷新。
- 完全本地运行；不采集、不上传账号数据、prompt、项目内容。
- 处理 Codex 未安装、未登录、app-server 超时、离线、返回空 usage、多账号切换等异常。

## 3. 架构建议（非强制）

| 模块 | 职责 | 建议实现 |
|---|---|---|
| MenuBar UI | 显示状态栏文字、图标、下拉详情、设置入口 | Swift / SwiftUI + AppKit NSStatusItem |
| UsageProvider | 抽象数据源，返回 UsageSnapshot | Swift protocol 或小型本地 helper |
| AppServerUsageProvider | 主数据源，调用 Codex app-server 的 `account/rateLimits/read` | Swift `Process` 或 Python helper |
| RolloutLogFallbackProvider | app-server 失败时解析本地 SQLite + rollout log | Swift SQLite 或 Python sqlite3 |
| Cache | 保存最近一次成功快照，避免 UI 空白 | `~/Library/Application Support/` 或 UserDefaults |
| Scheduler | 周期性刷新、退避、错误恢复 | Timer / async Task |

## 4. 主通道：Codex app-server / account/rateLimits/read

启动：

```bash
/Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://
```

向 stdin 写入 initialize：

```json
{
  "id": "codex-usage-bridge-init",
  "method": "initialize",
  "params": {
    "clientInfo": {
      "name": "codex-usage-menubar",
      "title": "Codex Usage Menu Bar",
      "version": "0.1.0"
    },
    "capabilities": {
      "experimentalApi": true,
      "requestAttestation": false,
      "optOutNotificationMethods": []
    }
  }
}
```

再发送读取请求：

```json
{
  "id": "codex-usage-rate-limits",
  "method": "account/rateLimits/read"
}
```

从 stdout 按行读 JSON，找到 `id == "codex-usage-rate-limits"` 的响应。若 `result` 存在，优先读取 `result.rateLimitsByLimitId[preferredLimitId]`，否则读取 `result.rateLimits`。

## 5. 需要解析的字段

| 字段 | 含义 | UI 用途 |
|---|---|---|
| `primary.usedPercent` | 短窗口 usage 百分比；Codex Buddy 显示为 5h | 状态栏主显示，例如 `5h 23%` |
| `secondary.usedPercent` | 长窗口 usage 百分比；Codex Buddy 显示为 7d | 状态栏或下拉详情显示 `7d 41%` |
| `primary.resetsAt` | 短窗口 reset Unix timestamp | 显示倒计时，例如 `2h 13m` |
| `secondary.resetsAt` | 长窗口 reset Unix timestamp | 显示倒计时，例如 `4d 6h` |
| `limitId` | 当前限额类型 ID | 用于多账号/多 limit 过滤与 debug |
| `limitName` | 当前限额显示名称 | 下拉详情/debug |

## 6. Python 最小验证脚本 （参考、非强制）

```python
#!/usr/bin/env python3
import json, select, subprocess, time
from pathlib import Path

codex = Path("/Applications/Codex.app/Contents/Resources/codex")

init_msg = {
    "id": "init",
    "method": "initialize",
    "params": {
        "clientInfo": {"name": "codex-usage-menubar", "title": "Codex Usage Menu Bar", "version": "0.1"},
        "capabilities": {"experimentalApi": True, "requestAttestation": False, "optOutNotificationMethods": []},
    },
}
read_msg = {"id": "usage", "method": "account/rateLimits/read"}

proc = subprocess.Popen(
    [str(codex), "app-server", "--listen", "stdio://"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)

for msg in (init_msg, read_msg):
    proc.stdin.write(json.dumps(msg, separators=(",", ":")) + "\n")
    proc.stdin.flush()

deadline = time.monotonic() + 5
try:
    while time.monotonic() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], 0.1)
        if not ready:
            continue
        line = proc.stdout.readline()
        if not line:
            break
        msg = json.loads(line)
        if msg.get("id") == "usage":
            print(json.dumps(msg.get("result"), ensure_ascii=False, indent=2))
            break
finally:
    proc.terminate()
```

## 7. Swift 侧实现提示

- 用 `Process` 启动 Codex CLI，`arguments = ["app-server", "--listen", "stdio://"]`。
- stdin 写入一行 JSON + 换行；stdout 按行读取。
- 给每次读取设置 3–5 秒超时；超时后 kill process，不要让后台堆积孤儿进程。
- 首版建议每次刷新启动一次短生命周期 app-server 进程，简单稳妥；后续可优化为常驻连接。
- 状态栏文字不要过长：推荐 `Cdx 5h 23%` 或 `5h 23 · 7d 41`。
- 超过 70% 可改变图标/文字颜色；macOS 状态栏文字本身颜色控制有限，可用 SF Symbol 或模板图标表达状态。

## 8. Fallback：读取 `~/.codex/state_5.sqlite` 与 rollout log

app-server 不可用时，可以走 Codex Buddy 的 fallback 路径：

```text
~/.codex/state_5.sqlite
  -> table: threads
  -> column: rollout_path
  -> 最近 updated_at / updated_at_ms 的 rollout log 文件
  -> tail JSONL
  -> payload.type == "token_count"
```

`token_count` 事件中常见字段：

```text
payload.info.total_token_usage.total_tokens
payload.rate_limits.primary.used_percent
payload.rate_limits.secondary.used_percent
payload.rate_limits.primary.resets_at
payload.rate_limits.secondary.resets_at
payload.rate_limits.limit_id
payload.rate_limits.limit_name
```

建议：fallback 只做兜底和 debug，不作为唯一主数据源。

## 9. 推荐 UsageSnapshot 数据模型

```swift
struct UsageSnapshot {
    let primaryPercent: Int        // 0...100, 5h
    let secondaryPercent: Int      // 0...100, 7d
    let primaryResetsAt: Date?
    let secondaryResetsAt: Date?
    let totalTokens: Int?
    let limitId: String?
    let limitName: String?
    let source: String             // app-server / rollout-log / cache
    let fetchedAt: Date
}
```

## 10. 刷新策略与错误处理

- 默认 30 秒刷新。
- app-server 连续失败 3 次后进入退避，例如 2 分钟刷新一次，同时 UI 显示 stale。
- 保留 last successful snapshot，失败时继续显示上次数据，并在详情里标注 last updated。
- 如果 Codex CLI 不存在，提示用户安装/更新 Codex 或选择 CLI 路径。
- 如果返回值没有 rateLimits，显示 `Usage unavailable`，不要猜测额度。
- 多账号场景下需要在详情里显示 `limitId` / `limitName` / `source`，方便判断是否读错账号。
- 此程序开机自启动，Codex还未启动时，可以显示空值，并继续刷新。

## 11. macOS App 交付建议

- 首版使用 SwiftUI + AppKit，`LSUIElement = true`，做无 Dock 图标的 menu bar app。
- 设置页：刷新间隔、Codex CLI 路径、是否启用 rollout fallback、开机自启动。
- 权限：一般不需要 Accessibility；读取 `~/.codex` 可能触发文件访问/沙盒问题。若上架 App Store 会很麻烦，建议先做非沙盒签名版。
- 日志：写到 `~/Library/Logs/CodexUsageMenuBar/`，不要记录 prompt、命令、文件路径细节，只记录错误码和数据源状态。
- 隐私：明确声明只读本机 Codex 状态，不上传数据。

## 12. 验收标准

- 顶部状态栏能显示 5h 与 7d usage 百分比。
- 下拉菜单能显示 reset 倒计时、last updated、source、limitId/limitName。
- Codex 未运行但已登录时，仍能通过 app-server 短进程读到 usage；若读不到，要有清晰错误。
- 断网、Codex 未安装、Codex 未登录、app-server 超时、SQLite 不存在时均不崩溃。
- 不依赖硬件，不启用 BLE，不需要 Codex 插件 hooks。
- 不向任何第三方服务器发送 usage、prompt、路径、账号信息。

## 13. 风险边界

- `account/rateLimits/read` 是 Codex 本地 app-server 的内部/实验性接口，不应承诺长期稳定。
- OpenAI/Codex 更新后可能改变返回结构，必须把解析逻辑做成可快速更新。
- SQLite fallback 更脆弱，建议隔离在单独 provider 中，失败不影响主 UI。
- 不要绕过账号权限，不要读取或展示 prompt 内容；本程序只关注 usage/rate limit。

## 14. 参考来源

- openelab-commits/codex-buddy: `https://github.com/openelab-commits/codex-buddy`
- 核心脚本：`plugins/codex-usage-stick/scripts/codex_usage_ble_bridge.py`
- README 中的显示字段：5h usage、7d usage、reset countdown、tokens、primary/secondary reset timestamp。
- OpenAI Codex usage/limits 的公开入口仍以 dashboard 与 Codex `/status` 为准；本方案使用本地内部实现细节。
