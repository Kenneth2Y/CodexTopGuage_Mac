# Codex 操作记录

- 时间戳：2026-07-01 15:59:20 CST
- 用户目标：修复 5h 剩余额度在 99% 或 100% 附近错误显示为 0% 的问题，并检查 7d 是否有同类问题。
- 已阅读的重要文件：
  - `Sources/CodexTopGuageMac/main.swift`
- 做过的修改：
  - 将 `percent(from:)` 重命名为 `percentValue(from:)`。
  - 删除 `number <= 1 ? number * 100 : number` 的比例换算逻辑。
  - 将 `usedPercent` 按真实百分比数值解释，例如 `1` 表示 1%，剩余显示为 99%。
- 关键决策与原因：
  - bug 原因是 `usedPercent == 1` 被误当成 100% 已用，导致剩余量显示为 0%。
  - 5h 和 7d 都共用同一个解析函数，因此 7d 也存在同类风险；本次在共用解析函数处统一修复。
- 未完成事项 / 风险 / 后续建议：
  - 若未来接口新增明确的 fraction 字段，应单独解析，不要和 `usedPercent` 混用。
