# Mac贴贴 (MacPastie)

> macOS 菜单栏窗口管理工具，16 种吸附位置 + 全局热键，完全免费。

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Version](https://img.shields.io/badge/version-1.0-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 功能

- **16 种窗口位置**：左/右/上/下半屏、四角、左右三等分、左右 2/3、全屏、居中
- **全局热键**：默认 `⌃⌥` 前缀，不抢焦点直接触发
- **多显示器**：支持移到下一屏（`⌃⌥⌘ →`）
- **菜单栏常驻**：不占 Dock，轻量后台运行

| 操作 | 默认快捷键 |
|------|-----------|
| 左半屏 | ⌃⌥ ← |
| 右半屏 | ⌃⌥ → |
| 上半屏 | ⌃⌥ ↑ |
| 下半屏 | ⌃⌥ ↓ |
| 左上角 | ⌃⌥ U |
| 右上角 | ⌃⌥ I |
| 左下角 | ⌃⌥ J |
| 右下角 | ⌃⌥ K |
| 全屏 | ⌃⌥ ↩ |
| 居中 | ⌃⌥ C |
| 左三等分 | ⌃⌥ D |
| 中三等分 | ⌃⌥ F |
| 右三等分 | ⌃⌥ G |
| 左 2/3 | ⌃⌥ E |
| 右 2/3 | ⌃⌥ T |
| 移到下一屏 | ⌃⌥⌘ → |

---

## 安装

### 方式一：下载安装包（推荐）

1. 前往 [Releases](../../releases) 页面，下载最新版 `Mac贴贴_v1.0.zip`
2. 解压，将 `Mac贴贴.app` 拖入 `/Applications`
3. 双击打开，macOS 会提示「无法验证开发者」，按以下任意一种方式处理：

**方式 A（推荐，图形界面）**

双击 App → 弹出"无法打开"提示 → 打开「系统设置 → 隐私与安全性」→ 往下滚，找到「已阻止使用"Mac贴贴"」→ 点「仍然打开」→ 再次确认 → 打开成功

**方式 B（右键打开）**

右键点击 App → 选择「打开」→ 弹窗中点「打开」

**方式 C（终端命令）**

```bash
xattr -cr /Applications/Mac贴贴.app
```
然后双击打开。

4. 首次打开后，授权辅助功能权限即可使用

> ⚠️ 本应用使用 ad-hoc 签名（无 Apple 开发者证书），以上提示均属正常现象，代码完全开源可审查。

### 方式二：源码编译

**环境要求**：macOS 13+、Xcode 15+、[xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
# 安装 xcodegen（如未安装）
brew install xcodegen

# 克隆仓库
git clone https://github.com/PMKang/Mac-TieTie.git
cd Mac-TieTie/MacPastie

# 生成 Xcode 项目
xcodegen generate

# 打开 Xcode 编译运行
open MacPastie.xcodeproj
```

---

## 使用

1. 打开 App，菜单栏出现 `⊞` 图标
2. 首次使用需授权**辅助功能**权限：系统提示时点「打开系统设置」→ 勾选 Mac贴贴
3. 切换到任意窗口，按快捷键即可吸附

---

## 关注作者

扫码关注微信公众号「**阿康AI探索号**」

AI 资讯 · 金融科技 · PM 踩坑记录 · AI 养虾实验 🦐

<img src="qrcode.jpg" width="160" />

---

## 项目结构

```
MacPastie/
├── Core/
│   ├── WindowManager.swift      # 窗口吸附（Accessibility API）
│   ├── HotkeyManager.swift      # 全局热键（Carbon）
│   └── ActivationManager.swift  # 本地状态管理
└── Views/
    ├── MenuPanelView.swift       # 主面板
    ├── SnapGridView.swift        # 吸附网格
    ├── PreferencesView.swift     # 偏好设置
    └── AboutView.swift           # 关于
```

**已知待修复：**
- [ ] 快捷键自定义（UI 已有，逻辑待完善）
- [ ] 多显示器跨屏移动优化

---

## License

MIT
