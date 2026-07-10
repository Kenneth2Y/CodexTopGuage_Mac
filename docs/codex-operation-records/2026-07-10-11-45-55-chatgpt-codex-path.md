# Codex 操作记录

- 时间戳：2026-07-10 11:45:55 CST
- 用户目标：修复 ChatGPT Codex 更新后，菜单栏工具因找不到旧版 `Codex.app` 可执行文件而无法读取额度的问题。
- 已阅读的重要文件：
  - `Sources/CodexTopGuageMac/main.swift`
  - `README.md`
  - `/Applications/ChatGPT.app/Contents/Info.plist`
- 已验证环境：
  - 新版应用位于 `/Applications/ChatGPT.app`，bundle identifier 仍为 `com.openai.codex`。
  - 内置 executable 位于 `/Applications/ChatGPT.app/Contents/Resources/codex`，并支持 `app-server`。
- 做过的修改：
  - 使用可执行文件候选列表自动发现 CLI，优先新版 ChatGPT 路径，同时保留旧版 `Codex.app` 路径兼容。
  - README 中英双语说明新版安装位置、兼容逻辑和新的排障命令。
- 关键决策与原因：
  - 不只把旧硬编码路径替换为新硬编码路径，避免仍在旧版 Codex.app 的用户受影响。
  - app-server 协议仍然存在，因此保持现有 `initialize` 和 `account/rateLimits/read` 通道，不引入不必要的数据源改动。
- 未完成事项 / 风险 / 后续建议：
  - `app-server` 仍为内部/实验性接口；未来若 ChatGPT Codex 修改协议，需重新验证请求和解析字段。
