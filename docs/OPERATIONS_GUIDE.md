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

## 验收清单

1. 左键：浮层只有五个开关（清洁 / 深色 / 防睡 / 滚轮反转 / 滚轮平滑）；点外面关；不掉到屏幕角落。
2. 右键：主窗口、开机自启、检查更新、退出可用；**无** Hide Menu Bar Icon；设置里**无** Show Menu Bar Icon。
3. 登录项拉起：不自动弹主窗口 / 设置；菜单栏图标仍在。用户主动从应用程序再开才可出示主窗口。
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
