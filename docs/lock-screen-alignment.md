# 锁屏文字定位依据

核对日期：2026-10-17。以下结论来自本机 macOS 27.0.1 的系统组件静态代码和公共 AppKit 字体排版测量。未锁屏、注销、注入系统进程、修改系统文件，也未读取认证信息。

## 可以确定的内容

- 锁屏显示用户信息的现代代码路径是 `LWDefaultScreenLockUI` → `LUI2UIController` → `LUI2MessageViewController`。
- 字体为 `NSFont.systemFont(ofSize: 13, weight: .regular)`，文字颜色白色，居中排列。
- 文字列宽 400 个逻辑点，外围滚动容器宽 416 点。外层水平中心向右补偿 8 点，使实际 400 点文字列回到屏幕中央。
- 不是所有机器通用的固定物理像素位置。位置由完整屏幕逻辑高度、较短边长度、字体度量及是否要求认证的布局状态共同计算，与桌面 Dock 的高度无关。

## 标准认证锁屏的计算

定义 `H` 为完整屏幕逻辑高度，`S = min(屏幕宽度, 屏幕高度)`，`D = floor(0.05 × S)` 为默认头像直径，`d = ceil(-font.descender)`。

系统的约束链（以下距离均向屏幕上方计算）：

1. 认证提示第一基线距离屏幕底部：`0.06 × H`。
2. 密码框下沿在提示基线上方 20 点；密码框高 28 点。
3. 用户名基线在密码框上沿上方 18 点。
4. 用户列表下沿在用户名基线上方 23 点。
5. 消息容器下沿在用户列表下沿上方 `C` 点，其中 `C = D + 14 - 7 + 44 - d = D + 51 - d`。

因此，单行消息容器（最小高 17 点）中心距离屏幕底部：

```text
bottomToContainerCenter = 0.06 × H + D + 148.5 - d
```

本机公共 AppKit 实测 13 点常规系统字体：`descender = -2.7421875`，所以 `d = 3`；单行排版矩形高 16 点。17 点容器内文字从顶部排版，下方多出 1 点。使用同字体、16 点高的 `NSAttributedString` 排版矩形居中绘制时，若要对齐其实际基线，应在容器中心基础上再向上补偿 0.5 点：

```text
bottomToGlyphLayoutCenter = 0.06 × H + D + 149 - d
```

以 `1710 × 1107` 逻辑点为例：`D = 55`，容器中心距底部 `266.92` 点，16 点文字排版矩形中心距底部 `267.42` 点。Retina 的物理像素需另乘缩放因子；不应把用户手机照片的像素直接当作屏幕逻辑坐标。

未要求认证的另一条约束分支将用户名基线直接放在提示基线上方 30 点，比上述链少 36 点。它不是标准要求 Touch ID／密码的锁屏布局。当前活动分支由锁屏运行状态决定，不能仅凭某个偏好设置可靠确定。

## 证据位置与复核方法

系统框架：`/System/Library/PrivateFrameworks/LoginUIKit.framework/Versions/A/LoginUIKit`，共享缓存内虚拟路径，UUID `233F8A48-6DB3-3BD1-97C7-E2ED060E4302`。

可用系统已有 Xcode `dyld_info -disassemble` 读取该路径，无须提取整个共享缓存。以下地址为该构建的未滑动地址，系统更新后不能直接复用。

| 证据 | 地址／指令范围 |
| --- | --- |
| 13 点常规字体 | `-[LUI2MessageViewController viewDidLoad]`：`0x1A394F2B8–0x1A394F2E4`，`fmov d0, #13` 后调用 `systemFontOfSize:weight:`；权重 GOT `0x1E0212010` 指向 `NSFontWeightRegular` |
| 白色、居中 | 同方法 `0x1A394F260–0x1A394F2AC`，`setAlignment:1`、`whiteColor`、`setTextColor:` |
| 容器宽 416、最小高 17、最高 68 | 同方法 `0x1A394EC48–0x1A394EC74`、`0x1A394F11C–0x1A394F214` |
| 文本列宽 400、初始最小高 17 | 同方法 `0x1A394F334–0x1A394F448`；共享数据 `0x1E4D8FD10` 的 double 为 400 |
| 高度随排版更新 | `-[LUI2MessageViewController _resizeTextView]` `0x1A394E9F4–0x1A394EB14`：读取所有 glyph 的 bounding rect，并更新文字、滚动容器高度约束；外层强约束仍保留最小 17、最大 68 |
| 水平 8 点补偿 | `+[LUI2MessageViewController centerXPadding]` `0x1A394F538` 返回 8；父布局 `0x1A38DD68C–0x1A38DD6D8` 将消息中心设为主视图中心加 8 |
| 提示基线距底部 6% 屏高 | `-[LUI2UIController _authMainHintContraintConstant]` `0x1A38DC854–0x1A38DC8A4`，常量 `0x1A3988E20` 为 double 0.06；父约束 `0x1A38DDFC4–0x1A38DE03C` |
| 消息与用户列表相对约束 C | `-[LUI2UIController _messageConstraintConstant]` `0x1A38DC9B4–0x1A38DCA40`，使用默认头像尺寸、-7、44 和向上取整后的字体下降部；连接处 `0x1A38DE5C4–0x1A38DE650` |
| 默认头像直径 5% 短边与 14 点高度余量 | `+[LUI2UserView userViewDimensionsForPercentageOfDefault:]` `0x1A390BDE8–0x1A390BEEC`，常量 `0x1A3988F78` 为 double 0.05；`+[LUI2UserView initialize]` 将高度上下余量各设为 7 |
| 密码框高 28 | `-[LUI2PasswordViewController viewDidLoad]` `0x1A38E4F88–0x1A38E506C`，背景高 28 且与控制器视图上下边对齐 |
| 提示／密码框 20、用户名／密码框 18、用户名／用户列表 23 | 父布局分别 `0x1A38DE274–0x1A38DE2D0`、`0x1A38DE398–0x1A38DE42C`、`0x1A38DE6D4–0x1A38DE728` |
| 是否要求认证控制两条用户名约束分支 | `-[LUI2UIController _updateUserNameLabelContraint]` `0x1A38DCC54–0x1A38DCCD4` |

入口二进制：`/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow`，SHA-256 `59aed05e3e14eaaf551aa4cc488205a72867f385c36620f991849687ac68058d`。REA `inspect_macho` 证据编号 `ev_d8eaff82c2bfeccd7e02553e5dbb103d56a65b5c6281edc4956f0e173c3c1029` 确认其依赖 LoginUIKit。该文件包含多个架构，本文入口地址引用 arm64e 首个切片。

- `-[LWDefaultScreenLockUI _load]` 在 `0x1000B1C54–0x1000B1C64` 创建 `LUI2UIController`，并在 `0x1000B24E8–0x1000B24F0` 将锁屏信息送入 `_setMessageText:`。
- `-[LWDefaultScreenLockUI _setMessageText:]` `0x1000BED04–0x1000BEDC8` 经 `messageViewController.messageTextView` 设置实际字符串。

## 精度边界

上述为该系统构建的静态约束推导；没有把“静态推导”描述为一次真实锁屏截图的逐像素验证。用户原有的手机锁屏照片可作大致位置交叉检查，不能消除透视、裁切、屏幕缩放和字体栅格化误差。

公共 AppKit 无窗口排版测量确认：默认 `NSTextView.textContainerInset=(0,0)`、`textContainerOrigin=(0,0)`、`lineFragmentPadding=5`，该英文句子的 glyph 排版高 16。这里的“文字中心”指排版矩形中心，不等于可见墨迹外接矩形中心；大写、下降字母和中文会改变墨迹视觉中心。

预设主要针对单行短句。长句换行后，系统文字列宽 400、容器最大高 68；若桌面应用采用不同宽度、段落间距或多行高度策略，需要另外对齐。系统更新、多用户视图、外接显示器、特殊企业登录界面及辅助功能状态尚未逐项运行验证，因此保留用户微调和保存位置的能力。
