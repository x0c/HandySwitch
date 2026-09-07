**语言：** [English](README.md) | 简体中文

# HandySwitch

<p align="center">
  <img src="docs/images/app-icon.png" width="128" height="128" alt="HandySwitch 应用图标">
</p>

HandySwitch 是一个**极简的 macOS 菜单栏开关浮层**。左键点图标就能拨日常用的几个开关——清洁模式、深色模式、防止睡眠、鼠标滚轮反转、鼠标滚轮平滑——不必再钻进系统设置。

它不是 OnlySwitch，也不是 Mos。没有功能超市，没有按应用滚动配置，也没有程序坞图标。开关就在菜单栏图标下面。

**需要 macOS 26 或更高版本。** 以 MIT 许可证开源。一切留在本机——无账号、无遥测。

<p align="center">
  <img src="docs/images/panel.png" width="360" alt="HandySwitch 菜单栏浮层，五个日常开关">
</p>

## 支持的平台

- **macOS 26+**（Apple 芯片与 Intel）
- **不支持 Windows / Linux。** 依赖 macOS 菜单栏、辅助功能、自动化（System Events 用于深色模式）以及本机输入 / 滚轮接口。

## 安装

### Homebrew（推荐）

```sh
brew tap x0c/tap
brew install --cask handy-switch
```

### 直接下载

从 [Releases](https://github.com/x0c/HandySwitch/releases/latest) 下载最新的**已签名并公证**的 `HandySwitch-x.y.z.dmg`，把 HandySwitch 拖进「应用程序」。

HandySwitch 会通过 [Sparkle](https://sparkle-project.org) 自动检查更新。也可在右键菜单或主窗口里点 **检查更新…**。

### 从源码构建

需要 Xcode 26+ 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```sh
git clone https://github.com/x0c/HandySwitch.git
cd HandySwitch
xcodegen generate
xcodebuild -project HandySwitch.xcodeproj -scheme HandySwitch -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData build
rm -rf /Applications/HandySwitch.app
ditto build/DerivedData/Build/Products/Release/HandySwitch.app /Applications/HandySwitch.app
open /Applications/HandySwitch.app
```

## 用法

1. 左键点菜单栏图标，在图标下方打开开关浮层；点外面关闭。
2. 右键可打开主窗口、开机自启、检查更新或退出；主窗口里同样有开机自启、检查更新与退出。
3. **清洁模式**与滚轮相关开关需要**辅助功能**；**深色模式**需要**自动化**（System Events）。打不开时按应用内提示去系统设置授权。
4. 清洁模式中，按住 **Esc** 约三秒退出（唯一出口）。
5. 开机自启默认关闭；登录项拉起时保持静默（不弹窗）。

## 功能

- 只放五个打磨过的开关，半成品不会出现在浮层里
- 清洁模式：全黑遮罩并拦截输入，方便擦屏 / 擦键
- 深色模式镜像系统外观（不是夜览）
- 防止睡眠支持预置时长
- 滚轮反转 / 平滑，不做按应用配置
- 菜单栏模板图标；无程序坞图标

## 明确不做

OnlySwitch 式功能超市、Mos 式按应用滚动 / 按键重映射 / 惯性物理、「隐藏桌面图标」冒充清洁模式、Mac App Store、沙盒，以及 Windows / Linux 客户端。

## 许可证

[MIT](LICENSE)
