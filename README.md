<p align="center">
  <img src="Assets/AppIcon.png" width="112" alt="DesktopLine app icon">
</p>
<h1 align="center">桌面一句 · DesktopLine</h1>
<p align="center"><strong>把一句话，轻轻放在桌面上。</strong></p>
<p align="center">原生 macOS 桌面文字 · 透明无边框 · 鼠标穿透 · 五个位置槽</p>
<p align="center">
  <a href="https://github.com/weekwu/DesktopLine/releases/latest">下载应用</a> ·
  <a href="#使用">使用指南</a> ·
  <a href="#这句话的出处">句子出处</a> ·
  <a href="README.en.md">English</a>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/self--checks-42%20passed-397261" alt="42 self checks passed locally">
  <img src="https://img.shields.io/badge/macOS-14%2B-173B42?logo=apple&logoColor=white" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Swift-AppKit-D5AA7C?logo=swift&logoColor=white" alt="Swift and AppKit">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-173B42" alt="MIT license"></a>
</p>

---

一段提醒、一句喜欢的话，或者一个还没完成的念头。DesktopLine 让它留在桌面上，像壁纸的一部分，又能随时修改。

**You'll never be ready.**

<img src="docs/assets/desktop.png" width="100%" alt="DesktopLine 实际桌面效果：白色短句位于桌面中下方，无可见窗口背景或边框">

<p align="center"><sub>真实桌面截图。DesktopLine 绘制的是中下方的白色短句；天气、诗词与系统监控卡片来自独立桌面工具。</sub></p>

## 留下文字，把界面收起来

| 能力 | 体验 |
|---|---|
| **只有文字** | 无标题栏、底板、描边或窗口阴影。普通应用窗口自然盖住它。 |
| **鼠标穿透** | 锁定后照常点击桌面、框选文件；解锁后可以直接拖动文字。 |
| **菜单栏编辑** | 修改句子、字号、字重、颜色、不透明度和换行宽度，即时保存。 |
| **五个位置槽** | 为不同桌面布局命名、保存、调用位置；同步恢复字号与字重，保留当前句子和颜色。 |
| **锁屏参考位置** | 根据本机研究过的标准锁屏布局生成预设，并提供单物理像素微调。 |
| **原生与本地** | Swift + AppKit，无第三方运行时、网络请求、遥测或定时轮询。 |

## 安装

从 [Releases](https://github.com/weekwu/DesktopLine/releases/latest) 下载 `DesktopLine-v1.1.0-macos-arm64.zip`，解压后把 **桌面一句.app** 拖入 **应用程序（Applications）** 文件夹，再打开应用。

- 发布下载包：**Apple Silicon，macOS 14 或更高版本**。
- 实际运行验证：**macOS 27.0.1 / Apple Silicon**；其他系统版本仍需反馈验证。
- Intel 用户可从源码构建；尚未在 Intel 硬件上实机验证。
- 下载包使用本地临时签名（ad-hoc），**尚未经过 Apple 开发者公证**。也可以选择下方的源码构建方式。

应用入口位于菜单栏的引号图标，不占用 Dock。首次启动会打开设置。安装本身不会自动添加开机启动；需要时，可在系统设置的登录项中添加应用。

## 使用

1. 点击菜单栏引号图标，选择 **编辑文字与样式…**。
2. 在 **文字与样式** 中输入句子，调整字号、字重和颜色。
3. 切换到 **位置与保存槽**，调整水平位置或距完整屏幕底部的距离。
4. 需要直接拖动时，点击 **解锁并拖动文字**；调整后点 **完成并锁定**。

关闭设置窗口也会恢复鼠标穿透。设置会即时保存，下一次启动保留，并默认锁定。

### 位置槽

选择一个槽，填写名称，再点击 **将当前位置存入此槽**。以后可在设置页或菜单栏直接调用。

- 槽 1：锁屏对齐参考，可自行微调后覆盖。
- 槽 2：首次升级或初始化时保留的原桌面位置。
- 槽 3–5：留给自己的布局。

每个槽保存位置、字号、字重、换行宽度和目标显示器。调用时，句子、颜色与可见状态继续使用当前设置。微调箭头每次移动 **1 个物理像素**：2× Retina 屏幕上即 0.5 pt。

### 关于锁屏对齐

锁屏位置与屏幕逻辑尺寸、字体度量和认证布局有关，**不是所有 Mac 通用的一组固定像素**。预设使用完整屏幕坐标，Dock 显隐不会改变锚点。

该参考来自 macOS 27.0.1 的现代标准 Touch ID／密码锁屏布局研究，字体为 **13 pt / 常规 / 居中**。在 1710×1107 pt 的示例屏幕上，单行文字排版中心距底部约 **267.42 pt**。

这是布局推导，尚未进行真实锁屏截图的逐像素核验。长句换行、系统版本、显示缩放或认证状态可能改变效果。可先点击 **还原锁屏槽** 重新计算当前主屏参考，再微调保存。详见 [锁屏定位说明](docs/lock-screen-alignment.md)。

## 这句话的出处

截图中的短句摘自 **Tim Cook（蒂姆·库克）** 于 **2019 年 6 月 16 日**在 **斯坦福大学第 128 届毕业典礼**上的演讲。斯坦福发布的官方讲稿，在结尾部分写道：

> “Graduates, the fact is, when your time comes, and it will, you’ll never be ready.”
>
> — Tim Cook, Stanford Commencement, June 16, 2019

他在这一段回顾乔布斯去世后承担领导责任的经历，区分事先做准备与真正面对变化：重要时刻到来时，未必会有完全准备好的感觉，仍然需要行动。这里保留这句话，作为开始做事的提醒。

来源：[Stanford Report · 2019 Commencement address by Apple CEO Tim Cook](https://news.stanford.edu/stories/2019/06/remarks-tim-cook-2019-stanford-commencement)。

## 从源码构建

需要 macOS 上已有的 Xcode 或 Command Line Tools，不需要额外安装依赖。

```sh
git clone https://github.com/weekwu/DesktopLine.git
cd DesktopLine
zsh build.sh
open './桌面一句.app'
```

默认构建当前机器架构，最低部署版本为 macOS 14。可用 `DESKTOPLINE_ARCH=arm64` 或 `DESKTOPLINE_ARCH=x86_64` 指定架构。临时编译缓存与图标中间文件会在构建退出时清理。

运行自检和查询当前屏幕参考：

```sh
./桌面一句.app/Contents/MacOS/DesktopLine --self-test
./桌面一句.app/Contents/MacOS/DesktopLine --screen-info
```

当前包含 **42 项自检**，覆盖旧设置迁移、五槽持久化、坐标转换、透明像素、窗口层级、锁定穿透和图标解码。真实多屏与锁屏行为仍需要实机观察。

```text
Sources/        原生应用、透明桌面窗口、设置与位置槽
Tests/          自检
Scripts/        图标生成
Assets/         图标矢量源与 PNG 预览
docs/           截图与定位说明
build.sh        构建应用并进行本地签名
```

## 数据与卸载

句子、样式和位置槽仅保存在本机：

```text
~/Library/Application Support/DesktopLine/settings.json
```

首次初始化会在默认句子尚未修改时复用已有的系统锁屏留言。应用不会向网络发送它，也不需要辅助功能、录屏或全盘访问权限。

卸载时先从菜单栏退出，再将应用移到废纸篓。要保留设置，保留上面的数据目录即可；要完全清除，再移除该专用目录以及 `local.week.DesktopLine` 的应用偏好。若自行添加过登录项，请同时移除它。

## 参与与许可

欢迎提交 [Issue](https://github.com/weekwu/DesktopLine/issues) 或改进，开发约定见 [CONTRIBUTING.md](CONTRIBUTING.md)，版本记录见 [CHANGELOG.md](CHANGELOG.md)。

代码和原创图标采用 [MIT License](LICENSE)。效果截图由项目作者提供；其中的 macOS、第三方界面、壁纸和其他作品的权利归各自权利人。演讲摘句按上述来源署名。
