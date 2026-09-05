<!-- managed:inherited-agents:start -->
<!-- source: /Users/geraltgraham/Codes/HandySwitch/AGENTS.md -->
# HandySwitch

通用工程规范：[Swift 规范](../_standards/swift.md)

HandySwitch 是本机极简菜单栏开关：点开就是几个开关，让日常用 Mac 更顺手。小学生一看名字就知道是「顺手开关」。

## 组件一览

| 目录 | 说明 | 状态 |
|---|---|---|
| `app-macos/` | macOS 客户端（独立 git 仓库） | 已交付，已公开开源 |

Remote：`app-macos` → GitHub 公开 [`x0c/HandySwitch`](https://github.com/x0c/HandySwitch)；Forgejo 私有镜像只留在本机 `git remote origin`，**禁止**把内网地址写进仓库。本产品文件夹不是 git 仓库。

**【裁定 2026-09-05】** 面向公众开源到 GitHub `x0c/HandySwitch`。许可证 MIT。只支持 macOS（绑定菜单栏、辅助功能、自动化与滚轮 API）。第一次公开发布就必须带齐签名公证安装包、应用内自更新、一键安装，不允许「先公开源码、发行以后再补」。更新清单和安装包发在源码仓自己的 Release，禁止另建更新仓。公开仓用当前树的干净快照历史，不要把私有开发史上的内网地址推上去。

## 钉死的体验

- 名字就是 **HandySwitch**，不要再换成谜语名或「Mac优化工具」品类名。
- **当前开关**：清洁模式、深色模式、防止睡眠、鼠标滚轮反转、鼠标滚轮平滑。没打磨完的功能禁止进菜单、设置、空态或快捷键。
- **菜单栏应用**：程序坞没有图标。左键打开开关浮层（贴图标下方，点外面关）；右键才是打开主窗口 / 开机自启 / 检查更新 / 退出。禁止把菜单常挂在状态项上。**图标即主入口：禁止隐藏菜单栏图标**。
- 开机自启默认关。不上 App Store。关沙盒。清洁与滚轮相关能力需要辅助功能权限；深色模式需要自动化（System Events）；缺权限时开关打不开并引导去系统设置。
- 中英文案。无系统蓝框。菜单栏模板图标。

用户可见行为权威说明见产品契约。

## 基线豁免

合法暂缓 / 不适用：

- **A2** 隐私清单：不收集、不上报用户数据。
- **B2** 全局快捷键：唤出不是靠热键，不适用。
- **B3** 账号登录：纯本地工具，无账号。
- **B5** App Intents：第一波没有要交给快捷指令的无人值守动作。
- **B7** 离线优先：无网络业务数据。

**A1 不再豁免。** 公开仓库的 macOS 图形应用必须具备 Developer ID 签名、公证 dmg、Sparkle 应用内自更新、Homebrew 一键安装。发版走 `app-macos/scripts/publish-release.sh`。

**下列不是豁免，必须过：** A3 中英、A4 无蓝框、A5 轻量主窗口位置记忆、A7 菜单栏模板图标、A8 版本双轨、B1 开机自启开关且默认关、关沙盒。

## 明确不做

- 按应用滚动配置、鼠标按键重映射、Mos 全套热键与惯性动量/弹跳/模拟触控板相位（平滑默认关相位，对齐 Mos）
- OnlySwitch / MacTools 式功能超市；**本机已卸 Mos 与 MacTools**，排滚轮问题前确认没有竞品再挂事件拦截
- 把「隐藏桌面图标」当成清洁模式
- 半成品开关或设置页堆功能
- 上架 Mac App Store；开沙盒
- 用 Java；做 Windows / Linux 客户端
- 注册 Now Playing / 远程媒体命令中心（会误触音乐播放）
- 提供「隐藏菜单栏图标」

## 文档导航

- [~/.config/agentsync/docs/MACOS_APP_DEVELOPMENT_GUIDE.md](~/.config/agentsync/docs/MACOS_APP_DEVELOPMENT_GUIDE.md)：改、评审或排查菜单栏图标、开机自启、恢复窗口或检查更新前**必读**。不读会在登录时弹出设置窗，或误加回「隐藏菜单栏图标」。
- [app-macos/AGENTS.md](app-macos/AGENTS.md)：改、评审或排查 macOS 客户端工程、菜单栏浮层、五开关、覆盖安装、公开开源或发版前**必读**。不读会把内网地址推进公开仓，或漏掉签名公证更新链路。
- [app-macos/docs/PRODUCT_CONTRACT.md](app-macos/docs/PRODUCT_CONTRACT.md)：改、优化、评审或排查浮层对齐与样式、防睡预置时长（点预置即开、禁止自定义输入）、开关的用户可见行为、清洁退出手势、媒体键禁令、防睡语义、深色模式（系统外观）、滚轮反转/平滑（含「开平滑不能滚 / 滚动时指针卡住」）、左右键分工或权限前**必读**。不读会把已锁体验改掉或重新引入音乐误触。
- [app-macos/docs/OPERATIONS_GUIDE.md](app-macos/docs/OPERATIONS_GUIDE.md)：构建、覆盖安装、五开关真机验收、公开发版前**必读**。
- [app-macos/docs/OPEN_SOURCE_BENCHMARK.md](app-macos/docs/OPEN_SOURCE_BENCHMARK.md)：改公开 README / Topics / 安装门面时**必读**。不读会对标漂移或漏掉截图与平台声明。
- [~/Codes/_standards/swift.md](../_standards/swift.md)：新建、评审或改造本 macOS 应用前**必读**。
- [~/Codes/_standards/workspace-docs/swift-docs/macos-app-baseline.md](../_standards/workspace-docs/swift-docs/macos-app-baseline.md)：脚手架、评审完整度前**必读**。
- [~/Codes/_standards/workspace-docs/swift-docs/macos-signing-notarization-distribution.md](../_standards/workspace-docs/swift-docs/macos-signing-notarization-distribution.md)：改签名、公证、Sparkle、Homebrew 或发版脚本前**必读**。

<!-- managed:inherited-agents:end -->

# HandySwitch app-macos

产品意图与开关契约见 [docs/PRODUCT_CONTRACT.md](docs/PRODUCT_CONTRACT.md)。本文件管工程与验收。

## Remote

- **公开**：GitHub [`x0c/HandySwitch`](https://github.com/x0c/HandySwitch)（本机 `github` remote；公开发布用当前树干净快照，不推私有开发史）。
- **私有镜像**：只留在本机 `origin`，**禁止**把内网地址、节点名或绝对个人路径写进将公开的文件。

## 工程约定

- 用 `xcodegen generate` 生成工程，禁止手改 `.xcodeproj`。
- Bundle ID：`top.caozc.HandySwitch`；展示名：`HandySwitch`。
- `LSUIElement`；关沙盒；依赖 MacKit ≥0.1.2（Core / LaunchAtLogin / Lifecycle）与 Sparkle（`SUPublicEDKey` + `SUFeedURL` 已配齐，允许 `startingUpdater: true`）。
- 左键浮层、右键菜单；图标常驻，无隐藏图标能力。
- **Apple Events（深色模式）**：`project.yml` 的 `entitlements.properties` **必须**含 `com.apple.security.automation.apple-events: true`（并同步落在 `HandySwitch.entitlements`），`Info.plist` 必须有 `NSAppleEventsUsageDescription`。**禁止**只写 `entitlements.path` 不写 `properties`——`xcodegen generate` 会把 plist 写成空 `<dict/>`，加固运行时下静默拒绝、不弹授权窗、自动化列表永远没有本应用。覆盖安装后执行：`codesign -d --entitlements :- /Applications/HandySwitch.app` 须能看到该键。
- **清洁模式退出**：仅按住 Esc 约 3 秒；禁止 ⌃⌘Esc 等其它捷径（见产品契约）。

## 本机覆盖安装

```bash
cd ~/Codes/HandySwitch/app-macos
xcodegen generate
xcodebuild -project HandySwitch.xcodeproj -scheme HandySwitch -configuration Release \
  -derivedDataPath build/DerivedData -destination 'platform=macOS' build
rm -rf "/Applications/HandySwitch.app"
ditto "build/DerivedData/Build/Products/Release/HandySwitch.app" "/Applications/HandySwitch.app"
xattr -dr com.apple.quarantine "/Applications/HandySwitch.app" 2>/dev/null || true
open "/Applications/HandySwitch.app"
```

公开发版（签名、公证、Sparkle、GitHub Release、Homebrew）：

```bash
scripts/publish-release.sh
```

## 文档导航

- [docs/PRODUCT_CONTRACT.md](docs/PRODUCT_CONTRACT.md)：改、优化、评审或排查浮层对齐与样式、防睡预置时长（点预置即开、禁止自定义输入）、深色模式（系统外观）、开关行为、滚轮反转/平滑（含「开平滑不能滚 / 滚动时指针卡住」）前**必读**。
- [docs/OPERATIONS_GUIDE.md](docs/OPERATIONS_GUIDE.md)：构建、覆盖安装、五开关真机验收、公开发版前**必读**。
- [docs/OPEN_SOURCE_BENCHMARK.md](docs/OPEN_SOURCE_BENCHMARK.md)：改公开 README / Topics / 安装门面时**必读**。
- [~/.config/agentsync/docs/MACOS_APP_DEVELOPMENT_GUIDE.md](~/.config/agentsync/docs/MACOS_APP_DEVELOPMENT_GUIDE.md)：菜单栏生命周期**必读**。
- [~/Codes/_standards/workspace-docs/swift-docs/macos-signing-notarization-distribution.md](~/Codes/_standards/workspace-docs/swift-docs/macos-signing-notarization-distribution.md)：签名公证分发**必读**。

## Sparkle

`Info.plist` 须含非空 `SUPublicEDKey` 与 `SUFeedURL`（指向本仓 `main` 上的 `appcast.xml`）。缺任一项时禁止 `startingUpdater: true`。发版由 `scripts/publish-release.sh` 生成并校验签名清单。
