# Codex 操作记录

- 时间戳：2026-06-30 22:32:46 CST
- 用户目标：将顶部栏显示从 usage 已用量改成 remaining 剩余量，格式改为 `Codex: 5h88% 7d67%`，并删除菜单里的 refresh 选项和 Refresh Now。
- 已阅读的重要文件：
  - `Sources/CodexTopGuageMac/main.swift`
  - `README.md`
- 做过的修改：
  - 状态栏标题改为显示剩余百分比：`100 - usedPercent`。
  - 状态栏格式改为 `Codex: 5hXX% 7dYY%`。
  - 菜单详情文案从 `usage` 改为 `remaining`。
  - 删除菜单里的 `Refresh: 5 seconds`、`Refresh: 10 seconds` 和 `Refresh Now`。
  - 保留内部 5 秒自动刷新，不再提供菜单调节。
  - README 中英双语说明同步更新。
- 关键决策与原因：
  - Codex app-server 返回的是已用百分比，因此剩余量用 `100 - usedPercent` 计算，并限制在 `0...100`。
  - 用户认为刷新调节没必要，因此菜单只保留信息项和 Quit。
- 未完成事项 / 风险 / 后续建议：
  - 若未来接口直接提供 remaining 字段，可改为优先读取接口字段，避免语义依赖。
