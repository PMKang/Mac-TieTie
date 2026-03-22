# Mac贴贴 开发复盘（2026-03-21）

## 总体结果
从零到跑通激活流程，一天内完成后端 + Swift App 骨架。主要卡点在微信消息推送连通性和网络环境问题。

---

## 坑点复盘

### 1. Vercel 区域选错
**坑**：默认部署到美国（iad1），微信服务器在大陆无法稳定连通，POST 事件全部丢失。
**教训**：涉及中国大陆服务器回调的项目，Vercel 必须选 `sin1`（新加坡）或 `hkg1`（香港）。
**做法**：`vercel.json` 里加 `"regions": ["sin1"]`。

---

### 2. 调试工具发的请求 ≠ 微信服务器发的请求
**坑**：微信「URL配置验证」调试工具是从用户**浏览器**发 GET 请求，User Agent 是 Chrome，不是微信真实服务器。我们一直以为验证通过了，其实微信服务器从未成功连接过。
**教训**：判断连通性要看 User Agent。真实微信服务器的 UA 是 `Mozilla/4.0`，浏览器调试工具是 `Mozilla/5.0 Chrome/xxx`。
**做法**：切换明文模式后点微信后台「提交」，才能触发真实服务器验证。

---

### 3. 代理工具（Clash Verge）干扰 App 网络请求
**坑**：
- Clash 开着 → 代理服务器返回错误页（非 JSON）→ Swift JSONSerialization 解析失败 → 报「数据格式错误」
- Clash 关着但系统代理未清除 → App 连不上 127.0.0.1:7897 → 超时
**教训**：用 `URLSession.shared` 会走系统代理设置，开发环境容易被代理工具干扰。
**做法**：用自定义 URLSession，设 `connectionProxyDictionary = [:]` 绕过系统代理直连。

---

### 4. macOS Accessibility 权限每次编译都失效
**坑**：Xcode 每次 ⌘R 重编译生成新二进制，签名变化，macOS 认为是新 App，Accessibility 权限自动撤销。
**教训**：这是 Xcode 开发阶段的正常现象，不是代码 bug。打正式包、签名固定后永久解决。
**临时方案**：
```bash
tccutil reset Accessibility com.akang.macpastie
```
重启 App 后重新授权。

---

### 5. macOS 13+ Settings 弹出方式变了
**坑**：`NSApp.sendAction(Selector(("showSettingsWindow:")), ...)` 在 macOS 13+ 报警告。
**原因**：macOS 13 引入了 SwiftUI Settings 场景，旧 selector 被弃用，仅适用于有 Settings scene 的 SwiftUI App。
**做法**：AppDelegate 模式的 App 直接用 NSWindow 包装 PreferencesView，自己管理窗口生命周期。

---

### 6. Popover 关闭后 App 失去激活状态
**坑**：点击「设置」或「关于」按钮 → `closePopover()` 先执行 → App 失去 Active 状态 → 新窗口/面板打开后不在最前。
**做法**：关闭 popover 后加 `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` 延迟，再调 `NSApp.activate(ignoringOtherApps: true)` 激活 App，然后弹窗口。

---

### 7. Swift Carbon 宏不能直接用
**坑**：`InstallApplicationEventHandler` 是 C 宏，Swift 无法调用。
**做法**：改用 `InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandler)`。

---

## 微信 POST 推送问题（未完全解决）

**现象**：GET URL 验证通过（真实微信服务器 Mozilla/4.0 GET 200），但用户关注/发消息无 POST 日志。
**待验证**：用非管理员微信账号关注公众号，看是否触发 POST 事件。

---

### 8. AXIsProcessTrustedWithOptions 每次快捷键都弹授权框
**坑**：`hasAccessibilityPermission()` 里用了 `kAXTrustedCheckOptionPrompt: true`，含义是「没授权就自动弹系统对话框」。每次按快捷键都调一次这个函数 → 每次都弹一次系统授权框 + 一次自定义 NSAlert，双重弹窗。
**做法**：改成 `AXIsProcessTrusted()`（静默检查），不授权时走我们自己的 `requestAccessibilityPermission()` 引导用户去系统设置，不让系统自动弹。

---

## 当前可用状态

| 功能 | 状态 |
|------|------|
| 后端 API 全部接口 | ✅ |
| Mac App 编译运行 | ✅ |
| 测试激活码 `AKANGDEV` | ✅ |
| 激活流程端到端 | ✅ |
| 窗口吸附（授权后）| ✅ |
| 设置/关于弹窗 | ✅ |
| 微信自动发激活码 | ⚠️ 待验证 |
