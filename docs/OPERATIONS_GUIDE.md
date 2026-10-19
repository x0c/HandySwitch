# 运维与验收

> 文档定位：构建、覆盖安装、五开关真机验收、公开发版操作与验收清单。

## 生成与构建

```bash
cd ~/Codes/HandySwitch/app-macos
xcodegen generate
xcodebuild -project HandySwitch.xcodeproj -scheme HandySwitch -configuration Release \
  -derivedDataPath build/DerivedData -destination 'platform=macOS' build
```

## 覆盖安装

见组件根 `AGENTS.md` 中的 ditto 命令。装完核对 About / 内部构建号。

## 公开发版

一条命令：`scripts/publish-release.sh`（签名 → 公证 → Sparkle appcast → GitHub Release → Homebrew cask）。本地私有配置见 `scripts/publish-local.env.example`。只做本机公证包可用 `--local-only`。

公开仓用干净快照历史；若本机 `origin`（Forgejo 私有镜像）与本地分叉，脚本会跳过推私有镜像并继续发 GitHub，**禁止**为此强推私有远端。

### 发版中断后怎么续（禁止盲目重跑整脚本）

通用中断续跑规则见 [macOS 应用签名、公证、分发与应用内自更新 §七](~/Codes/_standards/workspace-docs/swift-docs/macos-signing-notarization-distribution.md#七发版脚本骨架与本机优先原则)（发版脚本中断后续跑、快照推 main 成功推 tag 断线、raw CDN 滞后 rows）。本产品只记接线值：同一组 `publish-local.env`、`build/HandySwitch-<版>.dmg`、发版脚本 `scripts/publish-release.sh`，中断后按其后半段（重生 appcast、提交、推 GitHub 快照、Release 上传、Homebrew、匿名终检）续跑。

## 验收清单

1. 左键：浮层只有五个开关（清洁 / 深色 / 防睡 / 滚轮反转 / 滚轮平滑）；点外面关；不掉到屏幕角落。
2. 右键：主窗口、开机自启、检查更新、退出可用；**无** Hide Menu Bar Icon；设置里**无** Show Menu Bar Icon。主窗口须有开机自启、检查更新、退出对等入口。
3. 登录项拉起：不自动弹主窗口 / 设置；菜单栏图标仍在。用户主动从应用程序再开才可出示主窗口。菜单栏主入口：首次启动无配置窗；就绪后约 60 秒内再次打开须出主窗口。
4. Dark Mode：拨动后应先出现系统「控制 System Events」授权窗（若尚未决定）；允许后菜单栏 / Dock / 支持外观的应用整体切换深浅。`codesign -d --entitlements` 须含 `com.apple.security.automation.apple-events`。自动化列表里没有本应用时，不要只指路系统设置——应确认能力声明齐全后再拨一次；列表项只在弹过授权窗之后才出现。
5. Prevent Sleep 开：`pmset -g assertions` 能看到本应用断言；关或退出后消失。
6. Clean Mode：黑屏；媒体键不触发音乐；仅按住 Esc 约 3 秒可退出（⌃⌘Esc 无效）。
7. Reverse Mouse Scroll：外接鼠标滚轮方向反转；触控板自然滚动不受影响（需已授辅助功能）。
8. Smooth Mouse Scroll：外接鼠标开平滑后能连续滚；**滚动过程中指针仍可移动**；触控板不受影响。排障前确认本机没有 Mos / LinearMouse / 其它滚轮工具同时开着抢拦截。
9. 启动不弹 Sparkle「updater failed」；`Info.plist` 中 `SUPublicEDKey` 与 `SUFeedURL` 均非空；检查更新可拉到公开 feed。

## 浮层与防睡定时验收

- 打开菜单栏浮层：图标列、标题列、开关列分别对齐；五个开关主行等高；防睡预置条贴在主行下、不把该主行撑厚；中英文、深浅色均无裁字；菜单栏锚点不移动。
- 防止睡眠默认 5 小时；浮层只有 1 / 3 / 5 / 8 小时四个预置，**无**自定义输入与 Apply / Cancel。点预置即开启；再点其它预置按新时长重计。
- 开启后同时核对界面剩余时间与 `pmset -g assertions`；右侧开关关闭立即释放断言。
- 开启后退出 / 重启只恢复原截止时间，过期后重启保持关闭。

<!-- 该文档整理/压缩于 2026-09-05 -->

## Settings diagnostics (1.0.20)

- `DarkModeService.themeObserver`: keep the observer token MainActor-isolated and use Swift 6.2+ `isolated deinit` to remove it on the same actor, eliminating the unsafe annotation. The existing `@Observable` macro makes a plain `nonisolated` replacement invalid for its mutable backing storage. This target is macOS 26+ with Xcode 26+; the installed Swift 6.4 supports [SE-0371](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0371-isolated-synchronous-deinit.md). This does not alter automation requests or appearance switching.
- `SmoothScrollPoster` retains the existing Core Video display-link timing for this visual-only settings revision. `CVDisplayLinkCreateWithActiveCGDisplays` (creation), `CVDisplayLinkSetOutputCallback` (off-main timing callback), `CVDisplayLinkStart` (start), and the two `CVDisplayLinkStop` sites (explicit stop and drained-buffer stop) are deprecated since macOS 15 but still declared in the installed SDK. Each warning originates in the existing background interpolation mechanism, not the new Settings scene. Moving to AppKit display links changes callback ownership and scrolling behavior and requires physical mouse/pointer acceptance; it is not a diagnostic-only substitution. Residual risk: continued dependence on deprecated timing APIs. Follow-up: migrate the timer with real scroll/pointer and stop/restart evidence before those APIs are removed.
- `postToTarget` captures a non-Sendable `CGEvent` in `postQueue.async`; the related CoreGraphics preconcurrency-import suggestion has the same cause. The code creates an independent event with `template.copy()`, completes every mutation before enqueue, captures that single copy and never accesses it afterward. The stored template is not the posted instance. Inspection establishes exclusive use of this instance in the closure, so no shared mutation defect is established. Keep the warning visible rather than add an unchecked assertion or preconcurrency import. Residual risk: a future mutation after enqueue would break that ownership argument; follow-up: express or transfer the event data through a compiler-checked boundary during the scroll timing migration.
- The App Intents metadata skip comes from Xcode processing app/test targets without an AppIntents dependency; Settings introduces no intents or metadata consumer. Reassess when adding system automation capabilities.
- Sparkle's background scheduled-reminder warning is retained: the existing updater has no gentle-reminder delegate. Manual update checks remain standard Sparkle UI. A scheduled alert can be missed behind another app; a reminder policy must be designed separately rather than silence the support flag. Reference: [Sparkle gentle reminders](https://sparkle-project.org/documentation/gentle-reminders/).
- Under screen lock, AppKit reports that accessibility elements below its shield are not vended. Window-only images can still verify newly rendered static Settings content after a bounded display wake; they do not establish interactive controls or VoiceOver. A test-host startup also reported a layout-recursion diagnostic from the existing toggle panel; it occurs during the test host’s unconditional toggle-panel construction before Settings is requested. The panel’s synchronous geometry-to-frame callback is a candidate, not a confirmed stack trace. No new Settings layout call forces `layoutSubtreeIfNeeded`. Retain this startup diagnostic for a bounded panel-layout investigation with a breakpoint backtrace and physical acceptance; do not claim it resolved by the Settings build.

### Snapshot publication recovery

When GitHub main advanced outside this checkout, `ls-remote` can return a parent commit that is absent locally. Fetch `github main` before creating the clean-tree snapshot and use the fetched remote-tracking ref as its parent. A read-only remote hash alone is insufficient for `commit-tree`. Resume publication using the existing accepted/stapled artifacts; do not rebuild or resubmit notarization. Keep ordinary Git hooks active for the application and Homebrew commits.
