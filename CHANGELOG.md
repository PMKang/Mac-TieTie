# Mac贴贴 更新日志

## V0.2（2026-03-22）

### 新增 / 修复
- **自定义 About 面板**：显示公众号二维码、版本号、更新日志
- **修复设置/About 点不开**：`@NSApplicationDelegateAdaptor` 包装导致 `NSApp.delegate as? AppDelegate` 失败，改用 `AppDelegate.shared` 静态引用
- **移除下一屏功能**：单显示器时静默无效，体验差，直接屏蔽
- **补充安装说明**：新增系统设置 → 隐私与安全性解除 Gatekeeper 的操作路径

### 已知问题（待修复）
- 快捷键设置页面输入无效，点击按钮录入热键没反应

---

## V0.1.0（2026-03-21）

### 首个可用版本

#### 核心功能
- 菜单栏图标 + Popover 弹出面板（Tab 式：贴窗 / 截图🔒 / 资讯🔒）
- 15 种窗口吸附位置（左/右/上/下半屏、四角、三等分、左右2/3、全屏、居中）
- 全局热键（Carbon `RegisterEventHotKey`，默认前缀 ⌃⌥）
- 激活码系统（后端 Vercel + Supabase，微信公众号关注自动下发）
- 偏好设置窗口（快捷键自定义 + 通用选项）
- 登录启动（`SMAppService`，macOS 13+）

#### 后端
- Python FastAPI Serverless（Vercel sin1 新加坡节点）
- Supabase PostgreSQL 存储激活码与设备绑定
- 微信订阅号 URL 验证（明文模式，已通过微信服务器 GET 验证）

#### 已知限制
- 微信 POST 事件推送待非开发者账号验证
- 截图、资讯功能留待 V0.2 开发

---

### 调试踩坑记录（详见 RETROSPECTIVE.md）

| # | 问题 | 修复 |
|---|------|------|
| 1 | Vercel 部署在美东，微信服务器连不上 | 改 sin1（新加坡）|
| 2 | URL 验证工具是浏览器发的，不是微信服务器 | 切明文模式点「提交」看 Mozilla/4.0 UA |
| 3 | Clash Verge 代理拦截 App 网络请求 | URLSession `connectionProxyDictionary = [:]` 直连 |
| 4 | Xcode 每次重编译 Accessibility 权限失效 | `tccutil reset` + 重新授权；打包后永久解决 |
| 5 | macOS 13+ Settings selector 弃用 | AppDelegate 自建 NSWindow |
| 6 | Popover 关闭后 App 失去激活状态 | `asyncAfter(+0.1s)` + `NSApp.activate` |
| 7 | Carbon `InstallApplicationEventHandler` 是宏 Swift 不能调 | 改用 `InstallEventHandler(GetApplicationEventTarget(),...)` |
| 8 | `AXIsProcessTrustedWithOptions(prompt:true)` 每次弹窗 | 改用 `AXIsProcessTrusted()` 静默检查 |
| 9 | `Settings { PreferencesView() }` scene 与自定义 NSWindow 冲突 | App body 改为 `Settings { EmptyView() }` |
