//
//  ControlCenterView.swift
//  MacPastie - Dock 控制中心骨架
//

import SwiftUI

struct ControlCenterView: View {
    /// Allows existing control-center windows to navigate without creating a
    /// second window (for example from the legacy Preferences window).
    static let sectionRequestNotification = Notification.Name("MacPastie.controlCenter.requestSection")

    enum Section: String, CaseIterable, Identifiable {
        case snap = "贴窗"
        case crossScreen = "跨屏"
        case shortcuts = "快捷键配置"
        case settings = "设置"
        case about = "关于"

        var id: Self { self }

        var symbolName: String {
            switch self {
            case .snap: "rectangle.3.group.fill"
            case .crossScreen: "rectangle.2.swap"
            case .shortcuts: "command"
            case .settings: "gearshape"
            case .about: "info.circle"
            }
        }

        var subtitle: String {
            switch self {
            case .snap: "把窗口放到刚刚好的位置"
            case .crossScreen: "让窗口自然地跨过屏幕边界"
            case .shortcuts: "用你顺手的方式操作窗口"
            case .settings: "权限、启动与偏好设置"
            case .about: "反馈、联系与更多阿康作品"
            }
        }
    }

    @State private var selectedSection: Section

    init(initialSection: Section = .snap) {
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 860, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: Self.sectionRequestNotification)) { notification in
            if let section = notification.object as? Section {
                selectedSection = section
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("阿康的")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Mac 贴贴")
                        .font(.headline.weight(.semibold))
                }
            }
            .padding(.horizontal, 14)

            VStack(spacing: 6) {
                ForEach(Section.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.symbolName)
                                .frame(width: 20)
                            Text(section.rawValue)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedSection == section ? Color.accentColor : .clear)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(section.keyboardShortcut, modifiers: [.command, .option])
                    .accessibilityLabel("打开\(section.rawValue)页面")
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("v1.0.1")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 18)
        }
        .padding(.vertical, 22)
        .frame(width: 220)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 28, weight: .bold))
                Text(selectedSection.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 34)

            Divider()

            Group {
                switch selectedSection {
                case .snap:
                    SnapPage(hotkeyStore: .shared)
                case .crossScreen:
                    CrossScreenPage()
                case .shortcuts:
                    ShortcutConfigurationPage()
                case .settings:
                    SettingsPage()
                case .about:
                    AboutPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedSection.rawValue)页面")
    }
}

private extension ControlCenterView.Section {
    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .snap: "1"
        case .crossScreen: "2"
        case .shortcuts: "3"
        case .settings: "4"
        case .about: "5"
        }
    }
}

#Preview {
    ControlCenterView()
}
