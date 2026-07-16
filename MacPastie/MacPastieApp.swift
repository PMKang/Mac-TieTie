import AppKit

/// 纯菜单栏应用使用 AppKit 主循环，确保 Finder、登录启动和终端启动
/// 都执行同一条 AppDelegate 生命周期。
@main
enum MacPastieApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.finishLaunching()
        delegate.start()
        application.run()
    }
}
