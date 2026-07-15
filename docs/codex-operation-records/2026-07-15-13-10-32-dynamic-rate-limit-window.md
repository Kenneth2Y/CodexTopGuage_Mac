# Codex 操作记录

- 时间戳：2026-07-15 13:10:32 CST
- 用户目标：适配官方将 Codex 5 小时限额调整为单一 7 天限额后的显示变化，并兼容未来再次调整。
- 已阅读的重要文件：
  - `Sources/CodexTopGuageMac/main.swift`
  - `README.md`
- 已验证环境：
  - `account/rateLimits/read` 当前返回 `primary.windowDurationMins = 10080`、`primary.usedPercent = 8`。
  - 当前 `secondary = null`，因此旧 UI 将 7 天主窗口错误标成 `5h`，并额外显示无数据的 `7d--`。
- 做过的修改：
  - 解析 primary 和 secondary 的 `windowDurationMins`。
  - 顶部栏和菜单根据真实窗口分钟数动态生成 `5h`、`7d` 或其他时长标签。
  - 不再展示接口中不存在的窗口。
  - README 中英文功能说明和示例改为动态窗口显示。
- 关键决策与原因：
  - 采用动态窗口标签，而不是把 `5h` 直接硬编码改为 `7d`；这样官方恢复 5 小时或增加第二窗口时无需再次修改。
  - 保留 primary 为 `5h`、secondary 为 `7d` 的 fallback，只在旧接口不返回窗口时长时使用，以兼容旧版 Codex。
- 未完成事项 / 风险 / 后续建议：
  - `app-server` 是内部接口，若字段名或响应结构变化仍需适配。
