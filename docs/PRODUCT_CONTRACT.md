# HandySwitch 产品契约

> 文档定位：开关用户可见行为、清洁退出手势、媒体键禁令、防睡语义、深色模式、滚轮反转/平滑、左右键分工、权限引导、菜单栏恢复面。不读后果由根 AGENTS 导航写明。

## 产品一句话

菜单栏点开就是几个开关，让日常用 Mac 更顺手。

## App icon direction

- **User decision (2026-09-08): no clothespin.** The previous clothespin direction is revoked. Do not reuse it in new proposals or production assets.
- **Semantic requirement (2026-09-08):** proposals must visibly relate to switching and controlling the Mac through recognizable switches, push buttons, or sliders. Vary their form and composition; do not fill a direction board with unrelated objects such as leaves, fans, or paper airplanes. Visual novelty alone is insufficient.
- **Selected direction (2026-09-08):** a flat circular rotary knob with a small circular indicator at the upper right and a separate short rotation arc. The selected palette is bright turquoise background, deep teal knob and matching arc, and pale aqua indicator. Preserve the selected geometry and palette during independent master refinement. The user approved integration into the project app icon. Center the main circle on the canvas and preserve a balanced circle-to-canvas proportion; the separate upper-right arc must not pull the circle off center. Verify the result at small sizes before installation.
- Existing asset locations: `design/app-icon/AppIcon-1024.png` and `HandySwitch/Assets.xcassets/AppIcon.appiconset/`. The approved cyan artwork is integrated. At 1024 px the circle diameter is approximately 649 px (63.4%); its center is within 0.6% of canvas center.
- **Marketing / README icon:** `docs/images/app-icon.png` (referenced by `README.md` and `README.zh-CN.md`) must show the same rotary knob — never the revoked clothespin. When the App Icon master changes, regenerate this file from `design/app-icon/AppIcon-1024.png` (512×512 is enough for the README).

## Menu bar icon

- **User decision (2026-09-08):** use the same rotary-control motif as the approved App Icon. Preserve the circular body, upper-right circular indicator, and detached upper-right arc. Remove the turquoise background and map the indicator to a transparent hole in a monochrome template; the system supplies light/dark coloring. Keep existing left-click and right-click behavior. The 18 pt template is rebuilt by `scripts/generate-status-icon.py`, with 1x and 2x renditions in `StatusBarIcon.imageset`.

## 浮层样式（已锁）

- **外层玻璃 / 内层一整块实底（2026-09-10）**：整窗外框是贴菜单栏的玻璃功能层；标题「HandySwitch」与开关列表落在**同一块**圆角矩形实底上（系统 `windowBackgroundColor`），禁止标题字直接压在玻璃上，也**禁止**拆成标题卡 + 开关卡两块（用户否决分块后的缝隙观感）。
- 内卡片圆角与窗外框同心：外圆角 20、内边距 8 → 内卡片圆角 12。
- 没打磨完的半成品禁止进浮层。

## 左右键分工

| 操作 | 结果 |
|---|---|
| 左键点菜单栏图标 | 打开 / 关闭开关浮层；浮层贴在图标正下方；点外面关 |
| 右键或 Control+左键 | 系统菜单：Open Main Window、Launch at Login、Check for Updates…、Quit |

禁止把 `NSStatusItem.menu` 常挂在状态项上（会偷走左键）。

## 菜单栏与登录静默（已锁）

- **图标即主入口**：核心能力完全靠菜单栏图标（左键浮层）；**禁止**提供 Hide Menu Bar Icon / Show Menu Bar Icon，也禁止对外暴露写入「隐藏图标」的偏好路径。启动强制图标可见。
- **开机自启静默**：登录项拉起时零窗口——不自动打开主窗口 / 设置。用 `LoginLaunchDetector.isLaunchedAsLoginItem` + `MenuBarReopenPolicy.shouldShowRecoveryWindow(..., isLoginLaunch:)` 判定；用户主动从应用程序 / Spotlight / Dock 再次打开才可出示窗口。
- **右键与主窗口对等（2026-09-07）**：右键有的开机自启、检查更新、退出，主窗口须有同效入口（「打开主窗口」在已开窗时不必再挂）。权威见全局菜单栏开发指南裁定。
- **二次启动防呆（2026-09-07）**：首次用户启动零配置窗；后台就绪后默认 60 秒内再次从应用程序 / Spotlight 打开，须出示主窗口（`MenuBarReopenPolicy.presentation(..., menubarIsPrimaryEntry: true, secondsSinceReady:)`）。登录拉起除外。

## 五个开关

### 1. Clean Mode（清洁模式）

- **开**：每块屏幕盖全黑遮罩；系统级拦住键盘、鼠标、触控板、滚轮；隐藏光标；擦屏/擦键时不应有任何应用收到输入。
- **媒体键禁令**：必须吞掉系统定义键 / 媒体键，**禁止**注册 Now Playing 或远程媒体命令中心。验收：进入后按播放/暂停等媒体键，**不得**弹出或操控音乐。
- **退出手势**（唯一出口，遮罩上常显英文提示）：按住 Escape 约 3 秒。
- **禁止**其它退出捷径（含 ⌃⌘Esc / Control + Command + Escape、单按 Escape、点遮罩、菜单栏等）。
- **实现约束**：Esc 按下/抬起与秒表、异步开关均经主线程 Task 排队——**代际作废**见全局 [macOS 异步 UI 状态的代际作废](~/.config/agentsync/docs/MACOS_ASYNC_UI_STATE_GUIDE.md)；本产品按住约 3 秒。
- 退出后立刻恢复输入与光标；进程崩溃也不应留下永久锁输入（拦截随进程消失）。
- 缺辅助功能权限时：开关打不开，并提供一键跳到系统设置 › 隐私与安全性 › 辅助功能。
- 清洁模式是**瞬时会话**：开关表示「现在是否在清洁中」。退出手势成功后开关回到关。

### 2. Dark Mode（深色模式）

- **语义**：切换**系统外观**的深色 / 浅色，不是夜览（Night Shift）、不是只改本应用外观。
- **文案**：英文 `Dark Mode`；简体中文 `深色模式`（对齐系统设置用词；勿改成谜语名或做成夜览）。
- **开**：系统外观为深色；**关**：系统外观为浅色。若用户原先是「自动」，拨动本开关会退出自动、落到明确的深色或浅色（与系统设置 / 控制中心行为一致）。
- **镜像系统**：开关反映系统当前外观；在系统设置或控制中心改外观时，浮层打开时应同步。**不要**把深色状态写进本应用偏好并在启动时强行重放——会与系统「自动」和外部分切换打架。
- **权限与实现**：经 System Events 切换外观；加固运行时 / Apple Events /「自动化列表没有本应用」→ 全局 [macos-system-permissions.md](/Users/geraltgraham/Codes/_standards/workspace-docs/swift-docs/macos-system-permissions.md)。异步拨回须代际作废 → [MACOS_ASYNC_UI_STATE_GUIDE.md](~/.config/agentsync/docs/MACOS_ASYNC_UI_STATE_GUIDE.md)。
- 缺自动化权限时：开关打不开（或拨动后回弹）。**未弹过系统授权窗时，自动化列表本来就不会有 HandySwitch**——禁止把用户空指到设置里找；应引导再拨深色模式并点允许，列表项只在弹过窗之后才出现。仅当用户已拒绝后，才提供跳到系统设置 › 隐私与安全性 › 自动化。
- **禁止**用私有 SkyLight 外观 API 当主路径（易碎、难公证）；**禁止**做成 Night Shift / 色温开关却仍叫深色模式。

### 3. Prevent Sleep（防止睡眠 / Keep Awake）

- 开：进程内持有 `PreventUserIdleSystemSleep` 电源断言，阻止闲置系统睡眠 / 休眠。
- 关或退出应用：立刻释放断言，恢复用户能源偏好。
- **禁止**用 `pmset` 永久改系统设置；**禁止**靠常驻 `caffeinate` 子进程当主方案。
- 合盖睡眠等硬件强制行为无法也不应强行覆盖。
- **时长交互（2026-09-05 用户裁定）**：浮层里防睡行下方常显四个预置——**1 / 3 / 5 / 8 小时**。点任一预置即选用该时长并开启；默认预置为 5 小时。右侧开关仍可关 / 用当前所选时长再开。到期自动关闭。
- **禁止**自定义小时 / 分钟输入、Apply / Cancel、展开编辑面板或其它多步确认；不要再加「任意分钟」入口。
- **浮层行高（2026-09-05）**：五个开关的主行等高、图标/标题/开关垂直居中一致；防睡预置条是主行下方的次级条，不得给主行额外加厚上下边距，以免和其他行节奏错位。
- 保存结束时间；重启只恢复尚未到期的剩余时间，不能重新计满。旧版无截止时间的开启状态迁移为 5 小时。
- 运行中再点其它预置：从点击时按新时长重新计时。

### 4. Reverse Mouse Scroll（鼠标滚轮反转）

- 只反转**鼠标滚轮**方向（非 continuous 滚轮事件）。
- **不**改触控板自然滚动。
- 可与「平滑滚动」同时开：先反转再平滑。
- 需要辅助功能权限；缺权限时开关打不开并引导去系统设置。
- 开关状态持久化；开着时应用启动后应重新挂上事件拦截。

### 5. Smooth Mouse Scroll（鼠标滚轮平滑）

- 只对**鼠标滚轮**做插值平滑（把一格一格的滚轮变成更连续的像素滚动）。
- **不**改触控板；**不做**按应用配置、按键重映射、惯性动量全套、弹跳或「模拟触控板相位」（Mos 的 `smoothSimTrackpad` 默认关，我们也默认关）。
- **投递权威（2026-09-05，对齐 Mos）**：
  1. 拦截：`cgAnnotatedSessionEventTap` + `tailAppendEventTap`（不要用 HID head + 新建 session 事件当主路径）。
  2. 吞掉原格滚后，**复制原滚轮事件**作模板，刷新目标进程 PID（`eventTargetUnixProcessID`）。
  3. DisplayLink 插值写出 `scrollWheelEventPointDelta*`，`IsContinuous = 1`，打合成标记，再 **`postToPid`**。
  4. 默认**不**写 `scrollPhase` / `momentumPhase`。
  5. 格滚可用值小于 Mos 默认 `step`（33.6）时先归一到 step，再乘 `speed`（2.70）进缓冲；插值系数用 Mos `durationTransition`（约 0.085），死区约 1.0。
- **指针禁令**：禁止对全局 `post(tap:)` 的合成帧钉死滚轮开始时的旧 `location`——会把指针往回拽，表现为「一滚动鼠标就不能动」。Mos 用 `postToPid` 正是为了不进 session 重路由、不拽全局指针；进程内仍用事件自带 location 做窗口命中。
- **已否决弯路**：只改原事件再乱 `postToPid`（字段不齐）；新建 pixel 事件 + `cgSessionEventTap` + 长生命周期 `scrollPhase`（能滚但锁指针）。不要再把 LinearMouse 当主路径。
- **竞品与参考源（2026-09-05）**：本机已卸载 Mos、MacTools。排平滑/反转故障前先确认没有其它滚轮工具同时挂事件拦截。需要对照实现时，浅克隆到仓外一次性目录（如 `/tmp/ref-handyswitch/Mos`），**不要**假定 `/Applications/Mos.app` 还在。
- 与反转共用同一条滚轮拦截；合成事件须打标，避免被自己再次拦截。
- 需要辅助功能权限；缺权限时开关打不开并引导去系统设置。
- 开关状态持久化；开着时应用启动后应重新挂上事件拦截。
- **实现禁令**：工程默认 MainActor 隔离时，DisplayLink / 事件拦截相关类型必须标 `nonisolated`，否则 `CVDisplayLink` 线程会 `EXC_BREAKPOINT`。
- 超时被系统关掉的拦截须重新启用（或等价守护）。
- **用户可见症状触发词**：「开了平滑就不能滚」「滚动时鼠标指针不能动 / 被拽回去」——分别对照投递路径错误与指针禁令，不要先怪辅助功能开关。
## 权限

| 能力 | 权限 |
|---|---|
| 清洁模式 | 辅助功能（事件拦截） |
| 滚轮反转 / 平滑 | 辅助功能 |
| 深色模式（系统外观） | 自动化（控制 System Events）；加固运行时须声明 Apple Events |
| 防止睡眠 | 无额外隐私权限 |

## 文案与完成态

- 用户可见文案默认英文，并提供简体中文（跟随系统每应用语言）。
- 菜单栏完成态：打开主窗口、开机自启三态、检查更新入口、退出；**无**隐藏图标项。开机自启默认关；待批准不得显示成已开启；登录项拉起必须静默。**主窗口须含**开机自启、检查更新、退出（与右键对等）。
- **检查更新**：已配置 `SUPublicEDKey` 与 `SUFeedURL`（指向本仓公开 `appcast.xml`）后允许自动启动 Sparkle；缺任一项时禁止 `startingUpdater: true`，点检查更新则提示「尚未配置更新」。菜单与主窗口都要有入口。

## 明确不做

功能超市、按应用滚动配置、鼠标按键重映射、隐藏桌面图标当清洁、半成品入口、App Store / 沙盒、媒体命令中心。

<!-- 该文档整理/压缩于 2026-09-05 -->
