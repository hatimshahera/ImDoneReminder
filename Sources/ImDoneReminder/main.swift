import AppKit
import Foundation
import Network

struct ReminderEvent: Codable, Sendable {
    var source: String?
    var event: String?
    var label: String?
    var detail: String?
    var cwd: String?
    var sessionId: String?
    var turnId: String?

    var sourceLabel: String {
        clean(source) ?? "Agent"
    }

    var eventLabel: String {
        switch clean(event)?.lowercased() {
        case "permission", "approval", "needs-permission":
            return "needs approval"
        case "error", "failed":
            return "attention"
        default:
            return "done"
        }
    }

    var chatLabel: String {
        if let label = clean(label) {
            return label
        }

        if let cwd = clean(cwd) {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }

        if let turnId = clean(turnId) {
            return "turn \(turnId.prefix(8))"
        }

        if let sessionId = clean(sessionId) {
            return "session \(sessionId.prefix(8))"
        }

        return "this chat"
    }

    var bannerText: String {
        let source = sourceLabel.capitalized
        let prefix = "\(source) \(eventLabel)"
        let target = chatLabel

        if let detail = clean(detail) {
            return "\(prefix): \(target) - \(detail)"
        }

        return "\(prefix): \(target)"
    }

    var chatIdentity: String {
        clean(sessionId)
            ?? clean(cwd)
            ?? clean(label)
            ?? clean(turnId)
            ?? "\(sourceLabel)-unknown"
    }

    var chatCode: String {
        let seed = chatIdentity
        let hash = ReminderEvent.stableHash(seed)
        let code = String(hash % 0x10000, radix: 16, uppercase: true)
        return "#\(String(repeating: "0", count: max(0, 4 - code.count)))\(code)"
    }

    var privacySafeChatLabel: String {
        if let label = clean(label) {
            return label
        }

        if let cwd = clean(cwd) {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }

        return chatCode
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

enum DirectionPreference: String, CaseIterable {
    case random
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop

    var title: String {
        switch self {
        case .random: "Random"
        case .leftToRight: "Left to right"
        case .rightToLeft: "Right to left"
        case .topToBottom: "Top to bottom"
        case .bottomToTop: "Bottom to top"
        }
    }
}

enum PositionPreference: String, CaseIterable {
    case random
    case top
    case middle
    case bottom

    var title: String {
        switch self {
        case .random: "Random"
        case .top: "Top"
        case .middle: "Middle"
        case .bottom: "Bottom"
        }
    }

    var range: ClosedRange<CGFloat> {
        switch self {
        case .random: 0.05...0.95
        case .top: 0.72...0.95
        case .middle: 0.38...0.62
        case .bottom: 0.05...0.28
        }
    }
}

enum VehiclePreference: String, CaseIterable {
    case paperPlane
    case rocket
    case blimp
    case kite
    case comet

    var title: String {
        switch self {
        case .paperPlane: "Paper plane"
        case .rocket: "Rocket"
        case .blimp: "Blimp"
        case .kite: "Kite"
        case .comet: "Comet"
        }
    }
}

struct ReminderSettings {
    private enum Key {
        static let direction = "directionPreference"
        static let startPosition = "startPositionPreference"
        static let endPosition = "endPositionPreference"
        static let vehicle = "vehiclePreference"
        static let duration = "duration"
        static let textSize = "textSize"
        static let scale = "scale"
        static let showSource = "content.showSource"
        static let showEvent = "content.showEvent"
        static let showChatCode = "content.showChatCode"
        static let showChatLabel = "content.showChatLabel"
        static let showDetail = "content.showDetail"
        static let codexColor = "color.codex"
        static let claudeColor = "color.claude"
        static let cursorColor = "color.cursor"
        static let otherColor = "color.other"
        static let permissionColor = "color.permission"
        static let errorColor = "color.error"
    }

    var direction: DirectionPreference
    var startPosition: PositionPreference
    var endPosition: PositionPreference
    var vehicle: VehiclePreference
    var duration: TimeInterval
    var textSize: CGFloat
    var scale: CGFloat
    var showSource: Bool
    var showEvent: Bool
    var showChatCode: Bool
    var showChatLabel: Bool
    var showDetail: Bool

    static func load() -> ReminderSettings {
        let defaults = UserDefaults.standard
        return ReminderSettings(
            direction: DirectionPreference(rawValue: defaults.string(forKey: Key.direction) ?? "") ?? .random,
            startPosition: PositionPreference(rawValue: defaults.string(forKey: Key.startPosition) ?? "") ?? .random,
            endPosition: PositionPreference(rawValue: defaults.string(forKey: Key.endPosition) ?? "") ?? .random,
            vehicle: VehiclePreference(rawValue: defaults.string(forKey: Key.vehicle) ?? "") ?? .paperPlane,
            duration: defaults.object(forKey: Key.duration) as? TimeInterval ?? 9.0,
            textSize: defaults.object(forKey: Key.textSize) as? CGFloat ?? 24,
            scale: defaults.object(forKey: Key.scale) as? CGFloat ?? 1.0,
            showSource: bool(for: Key.showSource, default: true),
            showEvent: bool(for: Key.showEvent, default: true),
            showChatCode: bool(for: Key.showChatCode, default: true),
            showChatLabel: bool(for: Key.showChatLabel, default: true),
            showDetail: bool(for: Key.showDetail, default: true)
        )
    }

    private static func bool(for key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setDirection(_ direction: DirectionPreference) {
        UserDefaults.standard.set(direction.rawValue, forKey: Key.direction)
    }

    static func setStartPosition(_ position: PositionPreference) {
        UserDefaults.standard.set(position.rawValue, forKey: Key.startPosition)
    }

    static func setEndPosition(_ position: PositionPreference) {
        UserDefaults.standard.set(position.rawValue, forKey: Key.endPosition)
    }

    static func setVehicle(_ vehicle: VehiclePreference) {
        UserDefaults.standard.set(vehicle.rawValue, forKey: Key.vehicle)
    }

    static func setDuration(_ duration: Double) {
        UserDefaults.standard.set(duration, forKey: Key.duration)
    }

    static func setTextSize(_ size: Double) {
        UserDefaults.standard.set(size, forKey: Key.textSize)
    }

    static func setScale(_ scale: Double) {
        UserDefaults.standard.set(scale, forKey: Key.scale)
    }

    static func setShowSource(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.showSource)
    }

    static func setShowEvent(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.showEvent)
    }

    static func setShowChatCode(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.showChatCode)
    }

    static func setShowChatLabel(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.showChatLabel)
    }

    static func setShowDetail(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.showDetail)
    }

    static func color(for event: ReminderEvent) -> NSColor {
        switch event.event?.lowercased() {
        case "permission", "approval", "needs-permission":
            return color(forKey: Key.permissionColor, fallback: NSColor(calibratedRed: 0.91, green: 0.39, blue: 0.13, alpha: 1))
        case "error", "failed":
            return color(forKey: Key.errorColor, fallback: NSColor(calibratedRed: 0.80, green: 0.12, blue: 0.18, alpha: 1))
        default:
            let source = event.source?.lowercased() ?? "other"
            switch source {
            case "codex":
                return color(forKey: Key.codexColor, fallback: NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.58, alpha: 1))
            case "claude":
                return color(forKey: Key.claudeColor, fallback: NSColor(calibratedRed: 0.65, green: 0.28, blue: 0.17, alpha: 1))
            case "cursor":
                return color(forKey: Key.cursorColor, fallback: NSColor(calibratedRed: 0.35, green: 0.31, blue: 0.86, alpha: 1))
            default:
                return color(forKey: Key.otherColor, fallback: NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.58, alpha: 1))
            }
        }
    }

    static func color(forKey key: String, fallback: NSColor) -> NSColor {
        guard let hex = UserDefaults.standard.string(forKey: key) else { return fallback }
        return NSColor(hex: hex) ?? fallback
    }

    static func setColor(_ color: NSColor, forKey key: String) {
        UserDefaults.standard.set(color.hexString, forKey: key)
    }

    static var colorKeys: [(String, String, NSColor)] {
        [
            ("Codex", Key.codexColor, NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.58, alpha: 1)),
            ("Claude", Key.claudeColor, NSColor(calibratedRed: 0.65, green: 0.28, blue: 0.17, alpha: 1)),
            ("Cursor", Key.cursorColor, NSColor(calibratedRed: 0.35, green: 0.31, blue: 0.86, alpha: 1)),
            ("Other", Key.otherColor, NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.58, alpha: 1)),
            ("Permission", Key.permissionColor, NSColor(calibratedRed: 0.91, green: 0.39, blue: 0.13, alpha: 1)),
            ("Error", Key.errorColor, NSColor(calibratedRed: 0.80, green: 0.12, blue: 0.18, alpha: 1))
        ]
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        let rgb = usingColorSpace(.deviceRGB) ?? self
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}

@MainActor
final class ReminderApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let presenter = OverlayPresenter()
    private var server: ReminderServer?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        showSettings()

        do {
            server = try ReminderServer(port: 47777) { [weak self] event in
                Task { @MainActor in
                    self?.presenter.enqueue(event)
                }
            }
            server?.start()
        } catch {
            showLocalFailure("Could not start ImDoneReminder server: \(error.localizedDescription)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureMenu() {
        statusItem.button?.image = AppIconFactory.menuBarIcon()
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open ImDoneReminder", action: #selector(openSettings), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Support the creator", action: #selector(openCoffee), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func testDone() {
        presenter.enqueue(ReminderEvent(source: "codex", event: "done", label: "demo chat", detail: nil, cwd: nil, sessionId: nil, turnId: nil))
    }

    @objc private func testPermission() {
        presenter.enqueue(ReminderEvent(source: "claude", event: "permission", label: "website refactor", detail: "approval requested", cwd: nil, sessionId: nil, turnId: nil))
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func openCoffee() {
        if let url = URL(string: "https://buymeacoffee.com/hatimshahera") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = SettingsWindowFactory.makeWindow(
            onTestDone: { [weak self] in self?.testDone() },
            onTestPermission: { [weak self] in self?.testPermission() }
        )
        settingsWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showLocalFailure(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "ImDoneReminder"
        alert.informativeText = text
        alert.runModal()
    }
}

extension ReminderApp: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

@MainActor
enum SettingsWindowFactory {
    static func makeWindow(onTestDone: @escaping @MainActor () -> Void, onTestPermission: @escaping @MainActor () -> Void) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 650),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ImDoneReminder"
        window.center()
        window.contentView = makeContent(onTestDone: onTestDone, onTestPermission: onTestPermission)
        return window
    }

    private static func makeContent(onTestDone: @escaping @MainActor () -> Void, onTestPermission: @escaping @MainActor () -> Void) -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "ImDoneReminder")
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "Set up agent hooks, tune the flight, and make the little sky messenger yours. Settings save automatically.")
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let testDone = ActionButton(title: "Test done", actionHandler: onTestDone)
        testDone.translatesAutoresizingMaskIntoConstraints = false

        let testPermission = ActionButton(title: "Test permission", actionHandler: onTestPermission)
        testPermission.translatesAutoresizingMaskIntoConstraints = false

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(tab("Setup", view: setupView()))
        tabView.addTabViewItem(tab("Content", view: contentView()))
        tabView.addTabViewItem(tab("Colors", view: colorsView()))
        tabView.addTabViewItem(tab("Motion", view: motionView()))
        tabView.addTabViewItem(tab("Vehicle", view: vehicleView()))

        root.addSubview(title)
        root.addSubview(subtitle)
        root.addSubview(testDone)
        root.addSubview(testPermission)
        root.addSubview(tabView)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(lessThanOrEqualTo: testDone.leadingAnchor, constant: -16),
            testPermission.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            testPermission.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            testDone.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            testDone.trailingAnchor.constraint(equalTo: testPermission.leadingAnchor, constant: -8),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            tabView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 18),
            tabView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            tabView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            tabView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18)
        ])

        return root
    }

    private static func tab(_ title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }

    private static func setupView() -> NSView {
        SetupGuideView(pages: setupPages())
    }

    private static func setupPages() -> [SetupPage] {
        let script = setupScriptPath()
        return [
            SetupPage(
                title: "Codex",
                description: "Works for local Codex surfaces that load ~/.codex/config.toml hooks. Hosted/cloud-only sessions cannot call a command on your Mac.",
                prompt: """
                I use ImDoneReminder on this Mac. When this chat finishes a coding task, trigger the done reminder through the configured Codex hook. When you need permission, approval, or user input, trigger the permission reminder through the configured Codex hook.

                Keep reminder text short and private: use the project name or task name as the label, and use details like "done", "needs approval", or "needs input". Do not put secrets, file contents, API keys, personal data, or long chat text in the reminder.
                """,
                snippetTitle: "Paste into ~/.codex/config.toml",
                snippet: """
                [features]
                hooks = true

                [[hooks.Stop]]
                matcher = "*"
                [[hooks.Stop.hooks]]
                command = "\(script) auto --source codex --read-stdin"

                [[hooks.PermissionRequest]]
                matcher = "*"
                [[hooks.PermissionRequest.hooks]]
                command = "\(script) permission --source codex --read-stdin --permission-cooldown 120"
                """
            ),
            SetupPage(
                title: "Claude Code",
                description: "Works with Claude Code hooks on your Mac. The desktop/web chat app only works if it can run local hooks or shell commands.",
                prompt: """
                I use ImDoneReminder on this Mac. When this Claude Code chat finishes a coding task, trigger the done reminder through the configured Claude Code hook. When you need permission, approval, or user input, trigger the permission reminder through the configured Claude Code hook.

                Keep reminder text short and private: use the project name or task name as the label, and use details like "done", "needs approval", or "needs input". Do not put secrets, file contents, API keys, personal data, or long chat text in the reminder.
                """,
                snippetTitle: "Merge into ~/.claude/settings.json",
                snippet: """
                {
                  "hooks": {
                    "PermissionRequest": [
                      {
                        "matcher": "*",
                        "hooks": [
                          {
                            "type": "command",
                            "command": "\(script) permission --source claude --read-stdin --permission-cooldown 120"
                          }
                        ]
                      }
                    ],
                    "Stop": [
                      {
                        "matcher": "*",
                        "hooks": [
                          {
                            "type": "command",
                            "command": "\(script) auto --source claude --read-stdin"
                          }
                        ]
                      }
                    ]
                  }
                }
                """
            ),
            SetupPage(
                title: "Cursor",
                description: "Use this as a Cursor rule or prompt. Cursor support depends on whether the agent can run local shell commands in your workspace.",
                prompt: """
                I use ImDoneReminder on this Mac. When this Cursor chat finishes a coding task, run:
                \(script) done --source cursor --label "$(basename "$PWD")"

                When you need permission, approval, or human input, run:
                \(script) permission --source cursor --label "$(basename "$PWD")" --detail "needs input"

                Keep reminder text short and private. Do not include secrets, file contents, API keys, personal data, or long chat text in the reminder.
                """,
                snippetTitle: "Manual commands",
                snippet: """
                \(script) done --source cursor --label "$(basename "$PWD")"
                \(script) permission --source cursor --label "$(basename "$PWD")" --detail "needs input"
                """
            ),
            SetupPage(
                title: "Generic CLI",
                description: "Use with Aider, Gemini CLI, shell scripts, or any local agent that can run a command at completion.",
                prompt: """
                I use ImDoneReminder on this Mac. At the end of a coding task, run the done command below. If you need permission, approval, or input, run the permission command below.

                Keep reminder text short and private: use only a project/task label and a tiny status like "done" or "needs input". Do not include secrets, file contents, API keys, personal data, or long chat text.
                """,
                snippetTitle: "Commands",
                snippet: """
                \(script) done --source agent --label "$(basename "$PWD")"
                \(script) permission --source agent --label "$(basename "$PWD")" --detail "approval requested"
                """
            )
        ]
    }

    private static func setupScriptPath() -> String {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("scripts/imdone").path
        if FileManager.default.fileExists(atPath: current) {
            return current
        }
        return "<path-to-Im_done_reminder>/scripts/imdone"
    }

    static func snippetView(title: String, description: String, snippet: String) -> NSView {
        let view = NSView()

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = NSTextField(wrappingLabelWithString: description)
        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let textView = NSTextView()
        textView.string = snippet
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        scrollView.documentView = textView

        let copyButton = CopyButton(title: "Copy", snippet: snippet)
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(scrollView)
        view.addSubview(copyButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            copyButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: copyButton.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: copyButton.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])

        return view
    }

    private static func contentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        let settings = ReminderSettings.load()

        stack.addArrangedSubview(sectionTitle("Banner content"))
        stack.addArrangedSubview(note("Choose exactly what appears on the flying banner. Settings save automatically and apply to the next alert."))
        stack.addArrangedSubview(toggleRow(title: "Tool name", detail: "Shows Codex, Claude, Cursor, or Agent.", isOn: settings.showSource) { value in
            ReminderSettings.setShowSource(value)
        })
        stack.addArrangedSubview(toggleRow(title: "Event text", detail: "Shows finished coding, needs permission, or needs attention.", isOn: settings.showEvent) { value in
            ReminderSettings.setShowEvent(value)
        })
        stack.addArrangedSubview(toggleRow(title: "Chat color code", detail: "Shows the short per-chat code, such as #A31F.", isOn: settings.showChatCode) { value in
            ReminderSettings.setShowChatCode(value)
        })
        stack.addArrangedSubview(toggleRow(title: "Chat or project name", detail: "Shows the label/project name when available.", isOn: settings.showChatLabel) { value in
            ReminderSettings.setShowChatLabel(value)
        })
        stack.addArrangedSubview(toggleRow(title: "Extra detail", detail: "Shows text like approval requested or needs input.", isOn: settings.showDetail) { value in
            ReminderSettings.setShowDetail(value)
        })
        stack.addArrangedSubview(note("The colored stripe always remains visible so different chats can still be distinguished even with minimal text."))

        return stack
    }

    private static func colorsView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)

        stack.addArrangedSubview(sectionTitle("Colors by source and event"))
        stack.addArrangedSubview(note("These are used the next time a banner flies. Permission and error colors override source colors."))

        for (label, key, fallback) in ReminderSettings.colorKeys {
            stack.addArrangedSubview(colorRow(label: label, key: key, fallback: fallback))
        }

        return stack
    }

    private static func motionView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        let settings = ReminderSettings.load()

        stack.addArrangedSubview(sectionTitle("Motion"))
        stack.addArrangedSubview(note("Settings save automatically. Direction, start band, and end band are separate; each can be fixed or random."))
        stack.addArrangedSubview(popupRow(
            label: "Direction",
            options: DirectionPreference.allCases.map(\.title),
            selectedIndex: DirectionPreference.allCases.firstIndex(of: settings.direction) ?? 0
        ) { index in
            ReminderSettings.setDirection(DirectionPreference.allCases[index])
        })
        stack.addArrangedSubview(popupRow(
            label: "Start band",
            options: PositionPreference.allCases.map(\.title),
            selectedIndex: PositionPreference.allCases.firstIndex(of: settings.startPosition) ?? 0
        ) { index in
            ReminderSettings.setStartPosition(PositionPreference.allCases[index])
        })
        stack.addArrangedSubview(popupRow(
            label: "End band",
            options: PositionPreference.allCases.map(\.title),
            selectedIndex: PositionPreference.allCases.firstIndex(of: settings.endPosition) ?? 0
        ) { index in
            ReminderSettings.setEndPosition(PositionPreference.allCases[index])
        })
        stack.addArrangedSubview(sliderRow(label: "Speed", min: 4, max: 14, value: settings.duration, suffix: "s") { value in
            ReminderSettings.setDuration(value)
        })
        stack.addArrangedSubview(sliderRow(label: "Text size", min: 16, max: 36, value: settings.textSize, suffix: "pt") { value in
            ReminderSettings.setTextSize(value)
        })
        stack.addArrangedSubview(sliderRow(label: "Flight size", min: 0.75, max: 1.25, value: settings.scale, suffix: "x") { value in
            ReminderSettings.setScale(value)
        })

        return stack
    }

    private static func vehicleView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        let settings = ReminderSettings.load()

        stack.addArrangedSubview(sectionTitle("Vehicle"))
        stack.addArrangedSubview(note("The banner can be pulled by a paper plane, rocket, blimp, kite, or comet."))
        stack.addArrangedSubview(popupRow(
            label: "Flyer",
            options: VehiclePreference.allCases.map(\.title),
            selectedIndex: VehiclePreference.allCases.firstIndex(of: settings.vehicle) ?? 0
        ) { index in
            ReminderSettings.setVehicle(VehiclePreference.allCases[index])
        })
        stack.addArrangedSubview(note("Use the Test done or Test permission buttons at the top of this window after changing this. The next flight uses the saved setting."))
        return stack
    }

    private static func padded(_ view: NSView) -> NSView {
        let wrapper = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10),
            view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10),
            view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10),
            view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10)
        ])
        return wrapper
    }

    private static func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        return label
    }

    private static func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.widthAnchor.constraint(equalToConstant: 560).isActive = true
        return label
    }

    private static func colorRow(label: String, key: String, fallback: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let text = NSTextField(labelWithString: label)
        text.font = .systemFont(ofSize: 13, weight: .medium)
        text.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let well = ColorWell(key: key)
        well.color = ReminderSettings.color(forKey: key, fallback: fallback)
        well.widthAnchor.constraint(equalToConstant: 82).isActive = true

        row.addArrangedSubview(text)
        row.addArrangedSubview(well)
        return row
    }

    private static func toggleRow(title: String, detail: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let checkbox = CheckboxButton(title: title, isOn: isOn, onChange: onChange)
        checkbox.widthAnchor.constraint(equalToConstant: 170).isActive = true

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.widthAnchor.constraint(equalToConstant: 380).isActive = true

        row.addArrangedSubview(checkbox)
        row.addArrangedSubview(detailLabel)
        return row
    }

    private static func popupRow(label: String, options: [String], selectedIndex: Int, onChange: @escaping (Int) -> Void) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let text = NSTextField(labelWithString: label)
        text.font = .systemFont(ofSize: 13, weight: .medium)
        text.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let popup = PopupButton(options: options, onChange: onChange)
        popup.selectItem(at: selectedIndex)
        popup.widthAnchor.constraint(equalToConstant: 210).isActive = true

        row.addArrangedSubview(text)
        row.addArrangedSubview(popup)
        return row
    }

    private static func sliderRow(label: String, min: Double, max: Double, value: Double, suffix: String, onChange: @escaping (Double) -> Void) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let text = NSTextField(labelWithString: label)
        text.font = .systemFont(ofSize: 13, weight: .medium)
        text.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let valueLabel = NSTextField(labelWithString: String(format: "%.1f%@", value, suffix))
        valueLabel.widthAnchor.constraint(equalToConstant: 58).isActive = true

        let slider = Slider(value: value, minValue: min, maxValue: max) { newValue in
            valueLabel.stringValue = String(format: "%.1f%@", newValue, suffix)
            onChange(newValue)
        }
        slider.widthAnchor.constraint(equalToConstant: 270).isActive = true

        row.addArrangedSubview(text)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }
}

final class CopyButton: NSButton {
    private let snippet: String

    init(title: String, snippet: String) {
        self.snippet = snippet
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .rounded
        target = self
        action = #selector(copySnippet)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func copySnippet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.title = "Copy"
        }
    }
}

final class CheckboxButton: NSButton {
    private let onChange: (Bool) -> Void

    init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
        self.title = title
        setButtonType(.switch)
        state = isOn ? .on : .off
        target = self
        action = #selector(changed)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func changed() {
        onChange(state == .on)
    }
}

struct SetupPage {
    let title: String
    let description: String
    let prompt: String
    let snippetTitle: String
    let snippet: String
}

@MainActor
final class SetupGuideView: NSView {
    private let pages: [SetupPage]
    private let sidebar = NSStackView()
    private let content = NSView()
    private var selectedIndex = 0
    private var buttons: [NSButton] = []

    init(pages: [SetupPage]) {
        self.pages = pages
        super.init(frame: .zero)
        build()
        showPage(0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let root = NSStackView()
        root.orientation = .horizontal
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false

        sidebar.orientation = .vertical
        sidebar.spacing = 8
        sidebar.alignment = .leading
        sidebar.edgeInsets = NSEdgeInsets(top: 18, left: 14, bottom: 18, right: 10)
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        for (index, page) in pages.enumerated() {
            let button = NSButton(title: page.title, target: self, action: #selector(selectPage(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            button.widthAnchor.constraint(equalToConstant: 128).isActive = true
            buttons.append(button)
            sidebar.addArrangedSubview(button)
        }

        let sidebarBox = NSBox()
        sidebarBox.boxType = .custom
        sidebarBox.cornerRadius = 8
        sidebarBox.borderColor = NSColor.separatorColor
        sidebarBox.fillColor = NSColor.controlBackgroundColor
        sidebarBox.translatesAutoresizingMaskIntoConstraints = false
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebarBox.addSubview(sidebar)

        content.translatesAutoresizingMaskIntoConstraints = false

        root.addArrangedSubview(sidebarBox)
        root.addArrangedSubview(content)
        addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            sidebarBox.widthAnchor.constraint(equalToConstant: 156),
            sidebar.topAnchor.constraint(equalTo: sidebarBox.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: sidebarBox.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: sidebarBox.trailingAnchor),
            sidebar.bottomAnchor.constraint(lessThanOrEqualTo: sidebarBox.bottomAnchor),
            content.widthAnchor.constraint(greaterThanOrEqualToConstant: 460)
        ])
    }

    @objc private func selectPage(_ sender: NSButton) {
        showPage(sender.tag)
    }

    private func showPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        selectedIndex = index

        for (buttonIndex, button) in buttons.enumerated() {
            button.state = buttonIndex == index ? .on : .off
        }

        content.subviews.forEach { $0.removeFromSuperview() }
        let page = pages[index]
        let view = pageView(page)
        view.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: content.topAnchor),
            view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func pageView(_ page: SetupPage) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)

        let title = NSTextField(labelWithString: page.title)
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let description = NSTextField(wrappingLabelWithString: page.description)
        description.font = .systemFont(ofSize: 12)
        description.textColor = .secondaryLabelColor
        description.widthAnchor.constraint(equalToConstant: 470).isActive = true

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(description)
        stack.addArrangedSubview(codeSection(title: "Prompt to paste into the coding tool", text: page.prompt, height: 128))
        stack.addArrangedSubview(codeSection(title: page.snippetTitle, text: page.snippet, height: 210))
        return stack
    }

    private func codeSection(title: String, text: String, height: CGFloat) -> NSView {
        let wrapper = NSView()

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let copy = CopyButton(title: "Copy", snippet: text)
        copy.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.string = text
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        scroll.documentView = textView

        wrapper.addSubview(titleLabel)
        wrapper.addSubview(copy)
        wrapper.addSubview(scroll)

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: 488),
            wrapper.heightAnchor.constraint(equalToConstant: height + 30),
            titleLabel.topAnchor.constraint(equalTo: wrapper.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            copy.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            copy.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            scroll.heightAnchor.constraint(equalToConstant: height)
        ])

        return wrapper
    }
}

final class ActionButton: NSButton {
    private let actionHandler: @MainActor () -> Void

    init(title: String, actionHandler: @escaping @MainActor () -> Void) {
        self.actionHandler = actionHandler
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .rounded
        target = self
        action = #selector(runAction)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func runAction() {
        actionHandler()
    }
}

final class ColorWell: NSColorWell {
    private let storageKey: String

    init(key: String) {
        self.storageKey = key
        super.init(frame: .zero)
        target = self
        action = #selector(colorChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func colorChanged() {
        ReminderSettings.setColor(color, forKey: storageKey)
    }
}

final class PopupButton: NSPopUpButton {
    private let onChange: (Int) -> Void

    init(options: [String], onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero, pullsDown: false)
        addItems(withTitles: options)
        target = self
        action = #selector(selectionChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectionChanged() {
        onChange(indexOfSelectedItem)
    }
}

final class Slider: NSSlider {
    private let onChange: (Double) -> Void

    init(value: Double, minValue: Double, maxValue: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
        self.minValue = minValue
        self.maxValue = maxValue
        doubleValue = value
        target = self
        action = #selector(valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func valueChanged() {
        onChange(doubleValue)
    }
}

enum AppIconFactory {
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22))
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 22, height: 22).fill()

        let plane = NSBezierPath()
        plane.move(to: NSPoint(x: 3.5, y: 11.5))
        plane.line(to: NSPoint(x: 18.8, y: 17.2))
        plane.curve(
            to: NSPoint(x: 13.9, y: 5.1),
            controlPoint1: NSPoint(x: 20.0, y: 17.7),
            controlPoint2: NSPoint(x: 20.2, y: 16.7)
        )
        plane.line(to: NSPoint(x: 10.8, y: 8.4))
        plane.line(to: NSPoint(x: 7.8, y: 4.4))
        plane.curve(
            to: NSPoint(x: 6.3, y: 5.1),
            controlPoint1: NSPoint(x: 7.2, y: 3.7),
            controlPoint2: NSPoint(x: 6.3, y: 4.1)
        )
        plane.line(to: NSPoint(x: 5.6, y: 9.0))
        plane.line(to: NSPoint(x: 3.2, y: 10.0))
        plane.curve(
            to: NSPoint(x: 3.5, y: 11.5),
            controlPoint1: NSPoint(x: 2.3, y: 10.4),
            controlPoint2: NSPoint(x: 2.5, y: 11.3)
        )
        plane.close()
        NSColor.labelColor.setFill()
        plane.fill()

        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: 8.0, y: 5.0))
        fold.line(to: NSPoint(x: 12.5, y: 12.9))
        fold.line(to: NSPoint(x: 7.1, y: 9.2))
        fold.lineJoinStyle = .round
        NSColor.controlBackgroundColor.withAlphaComponent(0.82).setStroke()
        fold.lineWidth = 1.7
        fold.stroke()

        let check = NSBezierPath()
        check.move(to: NSPoint(x: 11.4, y: 9.4))
        check.line(to: NSPoint(x: 13.0, y: 7.8))
        check.line(to: NSPoint(x: 16.0, y: 12.0))
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.controlBackgroundColor.withAlphaComponent(0.82).setStroke()
        check.lineWidth = 1.8
        check.stroke()

        let trails = NSBezierPath()
        trails.move(to: NSPoint(x: 1.7, y: 7.2))
        trails.curve(to: NSPoint(x: 5.1, y: 8.3), controlPoint1: NSPoint(x: 2.8, y: 7.0), controlPoint2: NSPoint(x: 4.0, y: 7.3))
        trails.move(to: NSPoint(x: 2.8, y: 5.6))
        trails.curve(to: NSPoint(x: 6.0, y: 6.8), controlPoint1: NSPoint(x: 4.0, y: 5.5), controlPoint2: NSPoint(x: 5.0, y: 5.9))
        NSColor.labelColor.setStroke()
        trails.lineCapStyle = .round
        trails.lineWidth = 1.2
        trails.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

@MainActor
final class OverlayPresenter {
    private var queue: [ReminderEvent] = []
    private var isShowing = false
    private var activePanels: [NSPanel] = []

    func enqueue(_ event: ReminderEvent) {
        queue.append(event)
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard !isShowing, !queue.isEmpty else { return }

        isShowing = true
        let event = queue.removeFirst()
        show(event) { [weak self] in
            self?.isShowing = false
            self?.showNextIfNeeded()
        }
    }

    private func show(_ event: ReminderEvent, completion: @escaping @MainActor @Sendable () -> Void) {
        guard let screen = NSScreen.main else {
            completion()
            return
        }

        let frame = screen.frame
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        activePanels.append(panel)

        panel.contentView = PlaneBannerView(event: event) { [weak self, weak panel] in
            guard let self, let panel else {
                completion()
                return
            }

            panel.orderOut(nil)
            self.activePanels.removeAll { $0 === panel }
            completion()
        }
        panel.orderFrontRegardless()
    }
}

final class PlaneBannerView: NSView {
    private enum FlightRoute: CaseIterable {
        case climb
        case dive
        case highCruise
        case lowCruise
        case swoopUp
        case swoopDown
    }

    private enum VehicleEdge {
        case left
        case right
        case top
        case bottom
    }

    private let event: ReminderEvent
    private let completion: @MainActor @Sendable () -> Void
    private let startYRatio: CGFloat
    private let controlYRatioA: CGFloat
    private let controlYRatioB: CGFloat
    private let endYRatio: CGFloat
    private let startXRatio: CGFloat
    private let controlXRatioA: CGFloat
    private let controlXRatioB: CGFloat
    private let endXRatio: CGFloat
    private let settings: ReminderSettings
    private let direction: DirectionPreference
    private var startDate: Date?
    private var timer: Timer?
    private var progress: CGFloat = 0
    private var didFinish = false

    init(event: ReminderEvent, completion: @escaping @MainActor @Sendable () -> Void) {
        self.event = event
        self.completion = completion
        self.settings = ReminderSettings.load()

        let selectedDirection = settings.direction == .random
            ? DirectionPreference.allCases.filter { $0 != .random }.randomElement() ?? .leftToRight
            : settings.direction
        self.direction = selectedDirection

        let startBand = settings.startPosition == .random
            ? PositionPreference.allCases.filter { $0 != .random }.randomElement() ?? .middle
            : settings.startPosition
        let endBand = settings.endPosition == .random
            ? PositionPreference.allCases.filter { $0 != .random }.randomElement() ?? .middle
            : settings.endPosition

        let startRange = startBand.range
        let endRange = endBand.range
        let startValue = CGFloat.random(in: startRange)
        let endValue = CGFloat.random(in: endRange)

        let flightRoute = FlightRoute.allCases.randomElement() ?? .swoopUp
        switch flightRoute {
        case .climb:
            self.startYRatio = startValue
            self.controlYRatioA = min(1, startValue + CGFloat.random(in: 0.02...0.20))
            self.controlYRatioB = max(0, endValue - CGFloat.random(in: 0.02...0.20))
            self.endYRatio = endValue
        case .dive:
            self.startYRatio = startValue
            self.controlYRatioA = max(0, startValue - CGFloat.random(in: 0.02...0.20))
            self.controlYRatioB = min(1, endValue + CGFloat.random(in: 0.02...0.20))
            self.endYRatio = endValue
        case .highCruise:
            self.startYRatio = startValue
            self.controlYRatioA = min(1, max(startValue, endValue) + CGFloat.random(in: 0.04...0.18))
            self.controlYRatioB = min(1, max(startValue, endValue) + CGFloat.random(in: 0.00...0.14))
            self.endYRatio = endValue
        case .lowCruise:
            self.startYRatio = startValue
            self.controlYRatioA = max(0, min(startValue, endValue) - CGFloat.random(in: 0.00...0.14))
            self.controlYRatioB = max(0, min(startValue, endValue) - CGFloat.random(in: 0.04...0.18))
            self.endYRatio = endValue
        case .swoopUp:
            self.startYRatio = startValue
            self.controlYRatioA = max(0, min(startValue, endValue) - CGFloat.random(in: 0.12...0.28))
            self.controlYRatioB = min(1, max(startValue, endValue) + CGFloat.random(in: 0.12...0.28))
            self.endYRatio = endValue
        case .swoopDown:
            self.startYRatio = startValue
            self.controlYRatioA = min(1, max(startValue, endValue) + CGFloat.random(in: 0.12...0.28))
            self.controlYRatioB = max(0, min(startValue, endValue) - CGFloat.random(in: 0.12...0.28))
            self.endYRatio = endValue
        }

        self.startXRatio = startValue
        self.controlXRatioA = max(0, min(startValue, endValue) - CGFloat.random(in: 0.12...0.28))
        self.controlXRatioB = min(1, max(startValue, endValue) + CGFloat.random(in: 0.12...0.28))
        self.endXRatio = endValue

        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard window != nil, timer == nil else { return }

        startDate = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let startDate else { return }

        let elapsed = Date().timeIntervalSince(startDate)
        progress = min(1, elapsed / settings.duration)
        needsDisplay = true

        if progress >= 1 {
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }

        didFinish = true
        timer?.invalidate()
        timer = nil
        completion()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard bounds.width > 0, bounds.height > 0 else { return }

        let groupWidth = adaptiveGroupWidth(in: bounds)
        let groupHeight = adaptiveGroupHeight()
        let eased = easeInOut(progress)
        let center = centerPoint(for: eased, in: bounds, groupWidth: groupWidth, groupHeight: groupHeight)
        let groupRect = NSRect(
            x: center.x - groupWidth / 2,
            y: center.y - groupHeight / 2,
            width: groupWidth,
            height: groupHeight
        ).insetBy(dx: 10, dy: 10)

        drawFlightPath(in: bounds, groupWidth: groupWidth, groupHeight: groupHeight)

        let alpha = min(1, progress / 0.08) * min(1, (1 - progress) / 0.08)

        guard let graphicsContext = NSGraphicsContext.current else { return }
        graphicsContext.saveGraphicsState()
        graphicsContext.cgContext.setAlpha(alpha)

        drawBanner(in: groupRect)
        drawVehicle(in: groupRect)
        graphicsContext.restoreGraphicsState()
    }

    private func adaptiveGroupWidth(in bounds: NSRect) -> CGFloat {
        let textFont = NSFont.systemFont(ofSize: max(18, settings.textSize - 2), weight: .semibold)
        let textWidth = (bannerLine as NSString).size(withAttributes: [.font: textFont]).width

        var chipWidth: CGFloat = 0
        if settings.showSource {
            chipWidth += min(128, max(76, CGFloat(event.sourceLabel.count * 10 + 34))) + 8
        }
        let chatText = chatChipText()
        if !chatText.isEmpty {
            chipWidth += min(240, max(86, CGFloat(chatText.count) * 7.5 + 42))
        }

        let bannerWidth = max(340, min(max(textWidth + 72, chipWidth + 54), min(760, bounds.width * 0.56)))
        switch vehicleEdge {
        case .top, .bottom:
            return bannerWidth + 56
        case .left, .right:
            return bannerWidth + 112 + vehicleGap + 56
        }
    }

    private func adaptiveGroupHeight() -> CGFloat {
        switch vehicleEdge {
        case .top, .bottom:
            return 248 * settings.scale
        case .left, .right:
            return 172 * settings.scale
        }
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        value < 0.5
            ? 2 * value * value
            : 1 - pow(-2 * value + 2, 2) / 2
    }

    private func yPosition(for t: CGFloat, in bounds: NSRect, groupHeight: CGFloat) -> CGFloat {
        let safeMin = bounds.minY + 28
        let safeMax = bounds.maxY - groupHeight - 36
        let height = max(1, safeMax - safeMin)
        let y = cubic(
            t,
            startYRatio,
            controlYRatioA,
            controlYRatioB,
            endYRatio
        )
        return safeMin + height * max(0, min(1, y))
    }

    private func xPosition(for t: CGFloat, in bounds: NSRect, groupWidth: CGFloat) -> CGFloat {
        let safeMin = bounds.minX + groupWidth / 2 + 28
        let safeMax = bounds.maxX - groupWidth / 2 - 36
        let width = max(1, safeMax - safeMin)
        let x = cubic(t, startXRatio, controlXRatioA, controlXRatioB, endXRatio)
        return safeMin + width * max(0, min(1, x))
    }

    private func centerPoint(for t: CGFloat, in bounds: NSRect, groupWidth: CGFloat, groupHeight: CGFloat) -> NSPoint {
        let margin: CGFloat = 180
        switch direction {
        case .leftToRight:
            return NSPoint(
                x: bounds.minX - groupWidth / 2 - margin + (bounds.width + groupWidth + margin * 2) * t,
                y: yPosition(for: t, in: bounds, groupHeight: groupHeight) + groupHeight / 2
            )
        case .rightToLeft:
            return NSPoint(
                x: bounds.maxX + groupWidth / 2 + margin - (bounds.width + groupWidth + margin * 2) * t,
                y: yPosition(for: t, in: bounds, groupHeight: groupHeight) + groupHeight / 2
            )
        case .topToBottom:
            return NSPoint(
                x: xPosition(for: t, in: bounds, groupWidth: groupWidth),
                y: bounds.maxY + groupHeight / 2 + margin - (bounds.height + groupHeight + margin * 2) * t
            )
        case .bottomToTop:
            return NSPoint(
                x: xPosition(for: t, in: bounds, groupWidth: groupWidth),
                y: bounds.minY - groupHeight / 2 - margin + (bounds.height + groupHeight + margin * 2) * t
            )
        case .random:
            return NSPoint(
                x: bounds.minX - groupWidth / 2 - margin + (bounds.width + groupWidth + margin * 2) * t,
                y: yPosition(for: t, in: bounds, groupHeight: groupHeight) + groupHeight / 2
            )
        }
    }

    private func derivativePoint(for t: CGFloat, in bounds: NSRect, groupWidth: CGFloat, groupHeight: CGFloat) -> NSPoint {
        let margin: CGFloat = 180
        switch direction {
        case .leftToRight:
            return NSPoint(x: bounds.width + groupWidth + margin * 2, y: yDerivative(for: t, in: bounds))
        case .rightToLeft:
            return NSPoint(x: -(bounds.width + groupWidth + margin * 2), y: yDerivative(for: t, in: bounds))
        case .topToBottom:
            return NSPoint(x: xDerivative(for: t, in: bounds), y: -(bounds.height + groupHeight + margin * 2))
        case .bottomToTop:
            return NSPoint(x: xDerivative(for: t, in: bounds), y: bounds.height + groupHeight + margin * 2)
        case .random:
            return NSPoint(x: bounds.width + groupWidth + margin * 2, y: yDerivative(for: t, in: bounds))
        }
    }

    private func yDerivative(for t: CGFloat, in bounds: NSRect) -> CGFloat {
        let usableHeight = max(1, bounds.height - 220)
        let derivative =
            3 * pow(1 - t, 2) * (controlYRatioA - startYRatio) +
            6 * (1 - t) * t * (controlYRatioB - controlYRatioA) +
            3 * pow(t, 2) * (endYRatio - controlYRatioB)
        return derivative * usableHeight
    }

    private func xDerivative(for t: CGFloat, in bounds: NSRect) -> CGFloat {
        let usableWidth = max(1, bounds.width - 220)
        let derivative =
            3 * pow(1 - t, 2) * (controlXRatioA - startXRatio) +
            6 * (1 - t) * t * (controlXRatioB - controlXRatioA) +
            3 * pow(t, 2) * (endXRatio - controlXRatioB)
        return derivative * usableWidth
    }

    private func cubic(_ t: CGFloat, _ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> CGFloat {
        let mt = 1 - t
        return pow(mt, 3) * p0 + 3 * pow(mt, 2) * t * p1 + 3 * mt * pow(t, 2) * p2 + pow(t, 3) * p3
    }

    private func drawFlightPath(in bounds: NSRect, groupWidth: CGFloat, groupHeight: CGFloat) {
        let path = NSBezierPath()
        path.move(to: centerPoint(for: 0, in: bounds, groupWidth: groupWidth, groupHeight: groupHeight))
        path.curve(
            to: centerPoint(for: 1, in: bounds, groupWidth: groupWidth, groupHeight: groupHeight),
            controlPoint1: centerPoint(for: 0.34, in: bounds, groupWidth: groupWidth, groupHeight: groupHeight),
            controlPoint2: centerPoint(for: 0.68, in: bounds, groupWidth: groupWidth, groupHeight: groupHeight)
        )
        NSColor(calibratedWhite: 0.1, alpha: 0.08).setStroke()
        path.lineWidth = 2
        path.setLineDash([8, 10], count: 2, phase: progress * 32)
        path.stroke()
    }

    private func drawVehicle(in bounds: NSRect) {
        guard let graphicsContext = NSGraphicsContext.current else { return }
        let vehicleRect = vehicleRect(in: bounds)
        let orientationEdge = vehicleOrientationEdge

        graphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: vehicleRect.midX, yBy: vehicleRect.midY)

        switch orientationEdge {
        case .left:
            transform.scaleX(by: -1, yBy: 1)
        case .top:
            transform.rotate(byDegrees: 90)
        case .bottom:
            transform.rotate(byDegrees: -90)
        case .right:
            break
        }

        transform.translateX(by: -vehicleRect.midX, yBy: -vehicleRect.midY)
        transform.concat()
        drawVehicleShape(in: vehicleRect)
        graphicsContext.restoreGraphicsState()
    }

    private func drawVehicleShape(in vehicleRect: NSRect) {
        switch settings.vehicle {
        case .paperPlane:
            drawPlane(in: vehicleRect)
        case .rocket:
            drawRocket(in: vehicleRect)
        case .blimp:
            drawBlimp(in: vehicleRect)
        case .kite:
            drawKite(in: vehicleRect)
        case .comet:
            drawComet(in: vehicleRect)
        }
    }

    private func vehicleRect(in bounds: NSRect) -> NSRect {
        let bannerRect = bannerRect(in: bounds)

        switch vehicleEdge {
        case .left:
            return NSRect(x: bannerRect.minX - vehicleGap - 112, y: bounds.midY - 45, width: 112, height: 90)
        case .right:
            return NSRect(x: bannerRect.maxX + vehicleGap, y: bounds.midY - 45, width: 112, height: 90)
        case .top:
            return NSRect(x: bounds.midX - 56, y: bannerRect.maxY + vehicleGap, width: 112, height: 90)
        case .bottom:
            return NSRect(x: bounds.midX - 56, y: bannerRect.minY - vehicleGap - 90, width: 112, height: 90)
        }
    }

    private func bannerRect(in bounds: NSRect) -> NSRect {
        switch vehicleEdge {
        case .left:
            return NSRect(x: bounds.minX + 18 + 112 + vehicleGap, y: bounds.midY - 38, width: bounds.width - 36 - 112 - vehicleGap, height: 76)
        case .right:
            return NSRect(x: bounds.minX + 18, y: bounds.midY - 38, width: bounds.width - 36 - 112 - vehicleGap, height: 76)
        case .top:
            return NSRect(x: bounds.minX + 18, y: bounds.minY + 18, width: bounds.width - 36, height: 76)
        case .bottom:
            return NSRect(x: bounds.minX + 18, y: bounds.maxY - 94, width: bounds.width - 36, height: 76)
        }
    }

    private var vehicleEdge: VehicleEdge {
        switch direction {
        case .rightToLeft:
            return .left
        case .topToBottom:
            return .bottom
        case .bottomToTop:
            return .top
        case .leftToRight, .random:
            return .right
        }
    }

    private var vehicleOrientationEdge: VehicleEdge {
        guard settings.vehicle == .paperPlane else { return vehicleEdge }

        switch vehicleEdge {
        case .left:
            return .right
        case .right:
            return .left
        case .top:
            return .bottom
        case .bottom:
            return .top
        }
    }

    private var vehicleGap: CGFloat {
        46
    }

    private func drawPlane(in planeRect: NSRect) {
        let shadow = NSBezierPath()
        shadow.move(to: NSPoint(x: planeRect.minX + 10, y: planeRect.midY - 4))
        shadow.line(to: NSPoint(x: planeRect.maxX - 4, y: planeRect.maxY - 8))
        shadow.line(to: NSPoint(x: planeRect.maxX - 30, y: planeRect.midY + 4))
        shadow.line(to: NSPoint(x: planeRect.maxX - 4, y: planeRect.minY + 8))
        shadow.close()
        NSColor.black.withAlphaComponent(0.16).setFill()
        shadow.transform(using: AffineTransform(translationByX: 0, byY: -5))
        shadow.fill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: planeRect.minX + 6, y: planeRect.midY))
        path.line(to: NSPoint(x: planeRect.maxX - 4, y: planeRect.maxY - 8))
        path.line(to: NSPoint(x: planeRect.maxX - 30, y: planeRect.midY + 4))
        path.line(to: NSPoint(x: planeRect.maxX - 4, y: planeRect.minY + 8))
        path.close()

        NSColor(calibratedRed: 0.95, green: 0.99, blue: 1.0, alpha: 1).setFill()
        path.fill()
        accentColor.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 3
        path.stroke()

        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: planeRect.minX + 14, y: planeRect.midY))
        fold.line(to: NSPoint(x: planeRect.maxX - 30, y: planeRect.midY + 4))
        fold.line(to: NSPoint(x: planeRect.maxX - 50, y: planeRect.midY - 20))
        accentColor.withAlphaComponent(0.46).setStroke()
        fold.lineWidth = 3
        fold.stroke()
    }

    private func drawRocket(in vehicleRect: NSRect) {
        let rect = vehicleRect.insetBy(dx: 1, dy: 10)
        let body = NSBezierPath(roundedRect: NSRect(x: rect.minX + 18, y: rect.minY + 12, width: 72, height: 46), xRadius: 23, yRadius: 23)
        NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 1).setFill()
        body.fill()
        accentColor.setStroke()
        body.lineWidth = 3
        body.stroke()

        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: rect.maxX, y: rect.midY))
        nose.line(to: NSPoint(x: rect.minX + 84, y: rect.maxY - 10))
        nose.line(to: NSPoint(x: rect.minX + 84, y: rect.minY + 10))
        nose.close()
        accentColor.setFill()
        nose.fill()

        let flame = NSBezierPath()
        flame.move(to: NSPoint(x: rect.minX + 18, y: rect.midY))
        flame.line(to: NSPoint(x: rect.minX - 10, y: rect.maxY - 18))
        flame.line(to: NSPoint(x: rect.minX, y: rect.midY))
        flame.line(to: NSPoint(x: rect.minX - 10, y: rect.minY + 18))
        flame.close()
        NSColor(calibratedRed: 1, green: 0.63, blue: 0.18, alpha: 1).setFill()
        flame.fill()
    }

    private func drawBlimp(in vehicleRect: NSRect) {
        let rect = vehicleRect.insetBy(dx: -6, dy: 7)
        let body = NSBezierPath(ovalIn: NSRect(x: rect.minX, y: rect.minY + 12, width: 112, height: 52))
        NSColor(calibratedRed: 0.96, green: 0.99, blue: 1, alpha: 1).setFill()
        body.fill()
        accentColor.setStroke()
        body.lineWidth = 3
        body.stroke()

        let cabin = NSBezierPath(roundedRect: NSRect(x: rect.minX + 46, y: rect.minY, width: 34, height: 18), xRadius: 5, yRadius: 5)
        accentColor.withAlphaComponent(0.20).setFill()
        cabin.fill()
        accentColor.setStroke()
        cabin.lineWidth = 2
        cabin.stroke()
    }

    private func drawKite(in vehicleRect: NSRect) {
        let rect = NSRect(x: vehicleRect.midX - 46, y: vehicleRect.midY - 46, width: 92, height: 92)
        let kite = NSBezierPath()
        kite.move(to: NSPoint(x: rect.midX, y: rect.maxY))
        kite.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        kite.line(to: NSPoint(x: rect.midX, y: rect.minY))
        kite.line(to: NSPoint(x: rect.minX, y: rect.midY))
        kite.close()
        NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 1).setFill()
        kite.fill()
        accentColor.setStroke()
        kite.lineWidth = 3
        kite.stroke()

        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: rect.midX, y: rect.maxY))
        cross.line(to: NSPoint(x: rect.midX, y: rect.minY))
        cross.move(to: NSPoint(x: rect.minX, y: rect.midY))
        cross.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        accentColor.withAlphaComponent(0.45).setStroke()
        cross.lineWidth = 2
        cross.stroke()
    }

    private func drawComet(in vehicleRect: NSRect) {
        let rect = vehicleRect.insetBy(dx: 1, dy: 7)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: rect.minX, y: rect.midY))
        tail.line(to: NSPoint(x: rect.minX + 56, y: rect.maxY - 8))
        tail.line(to: NSPoint(x: rect.minX + 38, y: rect.midY))
        tail.line(to: NSPoint(x: rect.minX + 56, y: rect.minY + 8))
        tail.close()
        accentColor.withAlphaComponent(0.28).setFill()
        tail.fill()

        let core = NSBezierPath(ovalIn: NSRect(x: rect.maxX - 48, y: rect.midY - 24, width: 48, height: 48))
        NSColor(calibratedRed: 1, green: 0.98, blue: 0.82, alpha: 1).setFill()
        core.fill()
        accentColor.setStroke()
        core.lineWidth = 3
        core.stroke()
    }

    private func drawBanner(in bounds: NSRect) {
        let vehicleRect = vehicleRect(in: bounds)
        let bannerRect = bannerRect(in: bounds)

        let shadowRect = bannerRect.offsetBy(dx: 0, dy: -7)
        let shadow = NSBezierPath(roundedRect: shadowRect, xRadius: 16, yRadius: 16)
        NSColor.black.withAlphaComponent(0.18).setFill()
        shadow.fill()

        let rope = NSBezierPath()
        switch vehicleEdge {
        case .left:
            rope.move(to: NSPoint(x: bannerRect.minX, y: bannerRect.midY + 12))
            rope.curve(
                to: NSPoint(x: vehicleRect.maxX - 10, y: vehicleRect.midY + 6),
                controlPoint1: NSPoint(x: bannerRect.minX - 22, y: bannerRect.midY + 24),
                controlPoint2: NSPoint(x: vehicleRect.maxX + 22, y: vehicleRect.midY + 22)
            )
            rope.move(to: NSPoint(x: bannerRect.minX, y: bannerRect.midY - 12))
            rope.curve(
                to: NSPoint(x: vehicleRect.maxX - 10, y: vehicleRect.midY - 6),
                controlPoint1: NSPoint(x: bannerRect.minX - 22, y: bannerRect.midY - 24),
                controlPoint2: NSPoint(x: vehicleRect.maxX + 22, y: vehicleRect.midY - 22)
            )
        case .right:
            rope.move(to: NSPoint(x: bannerRect.maxX, y: bannerRect.midY + 12))
            rope.curve(
                to: NSPoint(x: vehicleRect.minX + 10, y: vehicleRect.midY + 6),
                controlPoint1: NSPoint(x: bannerRect.maxX + 22, y: bannerRect.midY + 24),
                controlPoint2: NSPoint(x: vehicleRect.minX - 22, y: vehicleRect.midY + 22)
            )
            rope.move(to: NSPoint(x: bannerRect.maxX, y: bannerRect.midY - 12))
            rope.curve(
                to: NSPoint(x: vehicleRect.minX + 10, y: vehicleRect.midY - 6),
                controlPoint1: NSPoint(x: bannerRect.maxX + 22, y: bannerRect.midY - 24),
                controlPoint2: NSPoint(x: vehicleRect.minX - 22, y: vehicleRect.midY - 22)
            )
        case .top:
            rope.move(to: NSPoint(x: bannerRect.midX - 26, y: bannerRect.maxY))
            rope.curve(
                to: NSPoint(x: vehicleRect.midX - 16, y: vehicleRect.minY + 8),
                controlPoint1: NSPoint(x: bannerRect.midX - 32, y: bannerRect.maxY + 18),
                controlPoint2: NSPoint(x: vehicleRect.midX - 32, y: vehicleRect.minY - 12)
            )
            rope.move(to: NSPoint(x: bannerRect.midX + 26, y: bannerRect.maxY))
            rope.curve(
                to: NSPoint(x: vehicleRect.midX + 16, y: vehicleRect.minY + 8),
                controlPoint1: NSPoint(x: bannerRect.midX + 32, y: bannerRect.maxY + 18),
                controlPoint2: NSPoint(x: vehicleRect.midX + 32, y: vehicleRect.minY - 12)
            )
        case .bottom:
            rope.move(to: NSPoint(x: bannerRect.midX - 26, y: bannerRect.minY))
            rope.curve(
                to: NSPoint(x: vehicleRect.midX - 16, y: vehicleRect.maxY - 8),
                controlPoint1: NSPoint(x: bannerRect.midX - 32, y: bannerRect.minY - 18),
                controlPoint2: NSPoint(x: vehicleRect.midX - 32, y: vehicleRect.maxY + 12)
            )
            rope.move(to: NSPoint(x: bannerRect.midX + 26, y: bannerRect.minY))
            rope.curve(
                to: NSPoint(x: vehicleRect.midX + 16, y: vehicleRect.maxY - 8),
                controlPoint1: NSPoint(x: bannerRect.midX + 32, y: bannerRect.minY - 18),
                controlPoint2: NSPoint(x: vehicleRect.midX + 32, y: vehicleRect.maxY + 12)
            )
        }
        NSColor(calibratedWhite: 0.12, alpha: 0.72).setStroke()
        rope.lineWidth = 2.5
        rope.stroke()

        let banner = NSBezierPath(roundedRect: bannerRect, xRadius: 16, yRadius: 16)
        NSColor(calibratedRed: 0.99, green: 0.995, blue: 1.0, alpha: 0.99).setFill()
        banner.fill()
        accentColor.withAlphaComponent(0.9).setStroke()
        banner.lineWidth = 3
        banner.stroke()

        let accentStripe = NSBezierPath(
            roundedRect: NSRect(x: bannerRect.minX + 8, y: bannerRect.minY + 8, width: 18, height: bannerRect.height - 16),
            xRadius: 9,
            yRadius: 9
        )
        chatColor.setFill()
        accentStripe.fill()

        let chipParagraph = NSMutableParagraphStyle()
        chipParagraph.alignment = .center
        var chipX = bannerRect.minX + 38
        if settings.showSource {
            let sourceChipRect = NSRect(x: chipX, y: bannerRect.maxY - 31, width: min(128, max(76, CGFloat(event.sourceLabel.count * 10 + 34))), height: 24)
            let chip = NSBezierPath(roundedRect: sourceChipRect, xRadius: 12, yRadius: 12)
            accentColor.withAlphaComponent(0.22).setFill()
            chip.fill()

            event.sourceLabel.uppercased().draw(in: sourceChipRect.insetBy(dx: 10, dy: 5), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .heavy),
                .foregroundColor: accentColor,
                .paragraphStyle: chipParagraph
            ])
            chipX = sourceChipRect.maxX + 8
        }

        let chatChipText = chatChipText()
        if !chatChipText.isEmpty {
            let chatChipRect = NSRect(x: chipX, y: bannerRect.maxY - 31, width: min(240, max(86, CGFloat(chatChipText.count) * 7.5 + 42)), height: 24)
            let chatChip = NSBezierPath(roundedRect: chatChipRect, xRadius: 12, yRadius: 12)
            chatColor.withAlphaComponent(0.26).setFill()
            chatChip.fill()

            let dot = NSBezierPath(ovalIn: NSRect(x: chatChipRect.minX + 9, y: chatChipRect.midY - 4, width: 8, height: 8))
            chatColor.setFill()
            dot.fill()

            chatChipText.draw(in: NSRect(x: chatChipRect.minX + 24, y: chatChipRect.minY + 5, width: chatChipRect.width - 32, height: 14), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 0.94),
                .paragraphStyle: chipParagraph
            ])
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(18, settings.textSize - 2), weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.055, alpha: 1),
            .paragraphStyle: paragraph
        ]

        let textRect = NSRect(x: bannerRect.minX + 38, y: bannerRect.minY + 13, width: bannerRect.width - 58, height: 32)
        bannerLine.draw(in: textRect, withAttributes: attributes)
    }

    private var bannerLine: String {
        var lead: [String] = []
        if settings.showSource {
            lead.append(event.sourceLabel.capitalized)
        }
        if settings.showEvent {
            lead.append(event.eventLabel)
        }

        var line = lead.joined(separator: " ")
        if settings.showChatLabel {
            if line.isEmpty {
                line = event.privacySafeChatLabel
            } else {
                line += ": \(event.privacySafeChatLabel)"
            }
        }

        if settings.showDetail, let detail = event.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            line = line.isEmpty ? detail : "\(line) - \(detail)"
        }

        if line.isEmpty {
            if settings.showChatCode {
                return event.chatCode
            }
            return event.eventLabel.capitalized
        }

        return line
    }

    private func chatChipText() -> String {
        var parts: [String] = []
        if settings.showChatCode {
            parts.append(event.chatCode)
        }
        if settings.showChatLabel {
            parts.append(event.privacySafeChatLabel)
        }
        return parts.joined(separator: " ")
    }

    private var accentColor: NSColor {
        ReminderSettings.color(for: event)
    }

    private var chatColor: NSColor {
        let hash = ReminderEvent.stableHash(event.chatIdentity)
        let hue = CGFloat(hash % 360) / 360
        return NSColor(calibratedHue: hue, saturation: 0.68, brightness: 0.72, alpha: 1)
    }
}

final class ReminderServer: @unchecked Sendable {
    private let listener: NWListener
    private let onEvent: @Sendable (ReminderEvent) -> Void

    init(port: UInt16, onEvent: @escaping @Sendable (ReminderEvent) -> Void) throws {
        self.listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.onEvent = onEvent
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: DispatchQueue(label: "imdone.reminder.server"))
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue(label: "imdone.reminder.connection"))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data else {
                connection.cancel()
                return
            }

            self.process(data)
            let body = "ok\n"
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/plain\r
            Content-Length: \(body.utf8.count)\r
            Connection: close\r
            \r
            \(body)
            """
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func process(_ data: Data) {
        guard let request = String(data: data, encoding: .utf8),
              let separator = request.range(of: "\r\n\r\n") else {
            return
        }

        let body = String(request[separator.upperBound...])
        guard let payload = body.data(using: .utf8),
              let event = try? JSONDecoder().decode(ReminderEvent.self, from: payload) else {
            return
        }

        onEvent(event)
    }
}

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    private let app = NSApplication.shared
    private let delegate = ReminderApp()

    func run() {
        app.delegate = delegate
        app.run()
    }
}

AppRuntime.shared.run()
