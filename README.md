<p align="center">
  <a href="#中文">简体中文</a> |
  <a href="#english">English</a> |
  <a href="LICENSE">MIT License</a>
</p>

# CodexTopGuage_Mac

## 中文

CodexTopGuage_Mac 是一个 macOS menu bar 小工具，用来在顶部状态栏显示本机 Codex usage 信息，例如 `Cdx 5h 23% 7d 41%`。

> 注意：本项目使用 Codex app-server 的内部/实验性 `account/rateLimits/read` 通道。它不是公开稳定 API，Codex 更新后可能需要调整解析逻辑。

### 功能

- 在 macOS 顶部状态栏显示 5h 和 7d usage 百分比。
- 点击菜单查看 reset 倒计时、数据来源、limit 信息和最后更新时间。
- 刷新间隔只能在 `5 seconds` 和 `10 seconds` 之间选择，默认 `5 seconds`。
- 完全本地运行，不上传 usage、prompt、项目路径或账号数据。
- Codex 未安装、未登录、接口超时或返回空数据时不会崩溃，会在菜单里显示错误状态。

### 系统要求

- macOS 13 或更新版本。
- Xcode Command Line Tools 或 Xcode。
- 已安装 Codex app，默认路径为 `/Applications/Codex.app`。
- Codex 已登录可用。

### 快速开始

```bash
git clone https://github.com/Kenneth2Y/CodexTopGuage_Mac.git
cd CodexTopGuage_Mac
swift build -c release
.build/release/CodexTopGuageMac
```

运行后，Dock 不会出现图标；请查看 macOS 顶部 menu bar。

### 本地开发

```bash
swift build
swift run CodexTopGuageMac
```

如果顶部栏显示 `Cdx --` 或菜单显示错误，请先确认 Codex 可执行文件存在：

```bash
ls -l /Applications/Codex.app/Contents/Resources/codex
```

### 数据来源

首版只实现主通道：

```text
/Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://
  -> initialize
  -> account/rateLimits/read
```

规划文档中的 SQLite / rollout log fallback 暂未实现，后续可作为独立 provider 加入。

### 打包建议

当前是 Swift Package 形式，适合源码安装和开发。后续可以增加 Xcode project、签名、notarization 和 `.dmg` 分发流程。

### 隐私

本工具只读取本机 Codex app-server 返回的 usage/rate limit 信息，不读取 prompt 内容，不扫描项目文件，不连接第三方服务器。

### 许可证

MIT。见 [LICENSE](LICENSE)。

## English

CodexTopGuage_Mac is a small macOS menu bar utility that shows local Codex usage in the status bar, for example `Cdx 5h 23% 7d 41%`.

> Note: this project uses the internal/experimental Codex app-server method `account/rateLimits/read`. It is not a stable public API, so future Codex updates may require parser changes.

### Features

- Shows 5h and 7d usage percentages in the macOS menu bar.
- Menu details include reset countdowns, data source, limit metadata, and last update time.
- Refresh interval is selectable only between `5 seconds` and `10 seconds`; the default is `5 seconds`.
- Runs fully locally. It does not upload usage, prompts, project paths, or account data.
- Handles missing Codex installation, login issues, timeouts, and unavailable usage without crashing.

### Requirements

- macOS 13 or later.
- Xcode Command Line Tools or Xcode.
- Codex app installed at the default `/Applications/Codex.app` path.
- A usable signed-in Codex session.

### Quick Start

```bash
git clone https://github.com/Kenneth2Y/CodexTopGuage_Mac.git
cd CodexTopGuage_Mac
swift build -c release
.build/release/CodexTopGuageMac
```

After launch, the app has no Dock icon. Check the macOS menu bar.

### Local Development

```bash
swift build
swift run CodexTopGuageMac
```

If the menu bar shows `Cdx --` or the menu reports an error, first verify the Codex executable:

```bash
ls -l /Applications/Codex.app/Contents/Resources/codex
```

### Data Source

The first version implements the main channel only:

```text
/Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://
  -> initialize
  -> account/rateLimits/read
```

The SQLite / rollout log fallback described in the planning brief is not implemented yet. It can be added later as a separate provider.

### Packaging

This repository is currently a Swift Package, suitable for source installation and development. An Xcode project, signing, notarization, and `.dmg` packaging can be added later.

### Privacy

This tool only reads usage/rate limit information returned by the local Codex app-server. It does not read prompt content, scan project files, or connect to third-party servers.

### License

MIT. See [LICENSE](LICENSE).
