# Codex 操作记录

- 时间戳：2026-06-30 22:38:37 CST
- 用户目标：说明手动退出后如何重新打开，评估 menu bar 空间遮挡问题，并把 `gauge.png` 运行截图显示到 GitHub README 首页。
- 已阅读的重要文件：
  - `README.md`
  - `gauge.png`
- 做过的修改：
  - 新增可双击启动脚本：`Start CodexTopGuage.command`
  - README 中文和英文部分均增加 `gauge.png` 运行截图。
  - README 增加手动重新打开说明。
  - README 增加 macOS menu bar 空间限制说明。
- 关键决策与原因：
  - 使用 `.command` 文件提供 Finder 双击入口，适合源码仓库阶段，无需立即引入 `.app` 打包流程。
  - 保留命令行启动和 LaunchAgent 自启动说明，覆盖手动启动、登录自启、重新登录恢复三种场景。
  - 明确 menu bar 遮挡属于 macOS 系统层面的空间分配行为，应用只能通过缩短标题降低影响。
- 未完成事项 / 风险 / 后续建议：
  - `.command` 首次运行可能触发 macOS 安全确认。
  - 后续正式发布可以提供 `.app` bundle 或 `.dmg`，用户体验会比双击 `.command` 更好。
