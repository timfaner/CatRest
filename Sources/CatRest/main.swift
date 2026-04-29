import AppKit
import ServiceManagement
import WebKit

private enum L10n {
    private enum Language: Equatable {
        case chinese
        case english
    }

    private static var language: Language {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? Locale.current.identifier.lowercased()
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }

    private static func text(zh: String, en: String) -> String {
        language == .chinese ? zh : en
    }

    static var idle: String { text(zh: "空闲", en: "Idle") }
    static var work: String { text(zh: "专注", en: "Work") }
    static var rest: String { text(zh: "休息", en: "Rest") }
    static var restComplete: String { text(zh: "休息结束", en: "Rest Complete") }
    static var restDone: String { text(zh: "休息完成", en: "Rest Done") }

    static var interruptRestTitle: String { text(zh: "适时休息，重获专注", en: "Time to rest and refocus") }
    static var restFinishedTitle: String { text(zh: "休息结束", en: "Rest Finished") }
    static var interruptRestSubtitle: String { text(zh: "可以继续下一轮，也可以多休息一分钟。", en: "Continue the next round, or rest for one more minute.") }
    static var restFinishedSubtitle: String { text(zh: "休息完成，选择接下来的节奏。", en: "Your break is complete. Choose the next pace.") }
    static var startPomodoro: String { text(zh: "开始番茄钟", en: "Start Pomodoro") }
    static var continuePomodoro: String { text(zh: "继续番茄钟", en: "Continue Pomodoro") }
    static var delayOneMinute: String { text(zh: "延迟 1 分钟", en: "Delay 1 Minute") }
    static var stopRest: String { text(zh: "停止休息", en: "Stop Rest") }
    static var endPomodoro: String { text(zh: "结束番茄钟", en: "End Pomodoro") }
    static var cancel: String { text(zh: "取消", en: "Cancel") }

    static var start: String { text(zh: "开始", en: "Start") }
    static var stop: String { text(zh: "停止", en: "Stop") }
    static var launchAtLogin: String { text(zh: "开机启动", en: "Launch at Login") }
    static var launchAtLoginRequiresApproval: String { text(zh: "开机启动（需要系统批准）", en: "Launch at Login (Approval Required)") }
    static var aboutCatRest: String { text(zh: "关于 CatRest", en: "About CatRest") }
    static var quitCatRest: String { text(zh: "退出 CatRest", en: "Quit CatRest") }
    static var openRestOptions: String { text(zh: "打开休息选项", en: "Open Rest Options") }
    static var workDurationTitle: String { text(zh: "工作时长", en: "Work Duration") }
    static var restDurationTitle: String { text(zh: "休息时长", en: "Rest Duration") }
    static var unableToUpdateLaunchAtLogin: String { text(zh: "无法更新开机启动", en: "Could Not Update Launch at Login") }
    static var authorInfo: String { text(zh: "作者：cyberpigeonb", en: "Author: cyberpigeonb") }
    static var openAuthorPage: String { text(zh: "打开作者主页", en: "Open Author Page") }
    static var close: String { text(zh: "关闭", en: "Close") }
    static var ok: String { text(zh: "知道了", en: "OK") }
    static var durationPrompt: String { text(zh: "请输入 1 到 240 分钟。", en: "Enter a duration from 1 to 240 minutes.") }
    static var save: String { text(zh: "保存", en: "Save") }

    static func workDurationMenu(minutes: Int) -> String {
        text(zh: "工作时长：\(minutes) 分钟...", en: "Work Duration: \(minutes) min...")
    }

    static func restDurationMenu(minutes: Int) -> String {
        text(zh: "休息时长：\(minutes) 分钟...", en: "Rest Duration: \(minutes) min...")
    }
}

private enum Phase: Equatable {
    case idle
    case work
    case rest
    case restComplete

    var label: String {
        switch self {
        case .idle: return L10n.idle
        case .work: return L10n.work
        case .rest: return L10n.rest
        case .restComplete: return L10n.restComplete
        }
    }
}

private enum Settings {
    private static let workSecondsKey = "workSeconds"
    private static let restSecondsKey = "restSeconds"
    private static let defaults = UserDefaults.standard

    static var workSeconds: Int {
        get { readDuration(key: workSecondsKey, fallback: 25 * 60) }
        set { defaults.set(clampedDuration(newValue), forKey: workSecondsKey) }
    }

    static var restSeconds: Int {
        get { readDuration(key: restSecondsKey, fallback: 5 * 60) }
        set { defaults.set(clampedDuration(newValue), forKey: restSecondsKey) }
    }

    private static func readDuration(key: String, fallback: Int) -> Int {
        let value = defaults.integer(forKey: key)
        return value > 0 ? clampedDuration(value) : fallback
    }

    private static func clampedDuration(_ seconds: Int) -> Int {
        min(max(seconds, 60), 240 * 60)
    }
}

private enum RuntimeOptions {
    static let autoStart = CommandLine.arguments.contains("--auto-start")
    static let autoContinueAfterRest = CommandLine.arguments.contains("--auto-continue-after-rest")
    static let workSecondsOverride = seconds(after: "--work-seconds")
    static let restSecondsOverride = seconds(after: "--rest-seconds")

    private static func seconds(after flag: String) -> Int? {
        guard let flagIndex = CommandLine.arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = CommandLine.arguments.index(after: flagIndex)
        guard CommandLine.arguments.indices.contains(valueIndex),
              let value = Int(CommandLine.arguments[valueIndex]),
              value > 0 else {
            return nil
        }
        return min(value, 240 * 60)
    }
}

private enum OverlayPromptKind {
    case interruptRest
    case restFinished

    var title: String {
        switch self {
        case .interruptRest:
            return L10n.interruptRestTitle
        case .restFinished:
            return L10n.restFinishedTitle
        }
    }

    var subtitle: String {
        switch self {
        case .interruptRest:
            return L10n.interruptRestSubtitle
        case .restFinished:
            return L10n.restFinishedSubtitle
        }
    }

    var options: [OverlayPromptOption] {
        switch self {
        case .interruptRest:
            return [
                OverlayPromptOption(title: L10n.startPomodoro, action: .continuePomodoro, style: .primary),
                OverlayPromptOption(title: L10n.delayOneMinute, action: .delayRest, style: .secondary),
                OverlayPromptOption(title: L10n.stopRest, action: .endPomodoro, style: .destructive),
                OverlayPromptOption(title: L10n.cancel, action: .cancel, style: .plain)
            ]
        case .restFinished:
            return [
                OverlayPromptOption(title: L10n.continuePomodoro, action: .continuePomodoro, style: .primary),
                OverlayPromptOption(title: L10n.delayOneMinute, action: .delayRest, style: .secondary),
                OverlayPromptOption(title: L10n.endPomodoro, action: .endPomodoro, style: .plain)
            ]
        }
    }
}

private enum OverlayAction {
    case continuePomodoro
    case delayRest
    case endPomodoro
    case cancel
}

private enum OverlayButtonStyle {
    case primary
    case secondary
    case destructive
    case plain
}

private struct OverlayPromptOption {
    let title: String
    let action: OverlayAction
    let style: OverlayButtonStyle
}

private struct CatVideoSet {
    let introURL: URL
    let loopURL: URL

    static func discover() -> CatVideoSet? {
        for directory in candidateDirectories() {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            let videos = urls
                .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            if let introURL = video(named: "v1", in: videos),
               let loopURL = video(named: "v2", in: videos) {
                return CatVideoSet(introURL: introURL, loopURL: loopURL)
            }

            if videos.count >= 2 {
                return CatVideoSet(introURL: videos[0], loopURL: videos[1])
            }
        }

        return nil
    }

    private static let supportedExtensions: Set<String> = ["webm", "mov", "mp4", "m4v"]

    private static func video(named name: String, in urls: [URL]) -> URL? {
        urls.first {
            $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    private static func candidateDirectories() -> [URL] {
        var directories: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            directories.append(resourceURL.appendingPathComponent("videos", isDirectory: true))
        }

        directories.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("videos", isDirectory: true))

        return directories
    }
}

private enum IconAssets {
    static func statusBarImage() -> NSImage? {
        loadImage(named: ["MenuBarCatClock@3x.png", "MenuBarCatClock@2x.png", "MenuBarCatClock.png"])
    }

    static func appIconImage(size: NSSize? = nil) -> NSImage? {
        guard let image = loadImage(named: ["AppIcon.icns", "CatRestIconSource.png", "MenuBarCatClock.preview.png"]) else {
            return nil
        }

        if let size {
            image.size = size
        }

        return image
    }

    private static func loadImage(named filenames: [String]) -> NSImage? {
        for directory in candidateDirectories() {
            for filename in filenames {
                let url = directory.appendingPathComponent(filename)
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        return nil
    }

    private static func candidateDirectories() -> [URL] {
        var directories: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            directories.append(resourceURL.appendingPathComponent("Assets", isDirectory: true))
            directories.append(resourceURL)
        }

        directories.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Assets", isDirectory: true))

        return directories
    }
}

private final class PomodoroTimer {
    private(set) var phase: Phase = .idle
    private var endDate: Date?
    private var timer: Timer?

    var onPhaseChanged: ((Phase, Int) -> Void)?
    var onTick: ((Phase, Int) -> Void)?

    var isRunning: Bool {
        phase != .idle
    }

    func start() {
        guard phase == .idle else { return }
        beginWork()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        phase = .idle
        onPhaseChanged?(.idle, 0)
        onTick?(.idle, 0)
    }

    func continuePomodoro() {
        guard phase == .rest || phase == .restComplete else { return }
        beginWork()
    }

    func delayRest(by seconds: Int) {
        let duration = min(max(seconds, 1), 60 * 60)

        switch phase {
        case .rest:
            endDate = (endDate ?? Date()).addingTimeInterval(TimeInterval(duration))
            let remaining = max(0, Int(ceil((endDate ?? Date()).timeIntervalSinceNow)))
            onTick?(.rest, remaining)
        case .restComplete:
            begin(phase: .rest, duration: duration)
        case .idle, .work:
            break
        }
    }

    private func beginWork() {
        begin(phase: .work, duration: RuntimeOptions.workSecondsOverride ?? Settings.workSeconds)
    }

    private func beginRest() {
        begin(phase: .rest, duration: RuntimeOptions.restSecondsOverride ?? Settings.restSeconds)
    }

    private func begin(phase newPhase: Phase, duration: Int) {
        timer?.invalidate()
        phase = newPhase
        endDate = Date().addingTimeInterval(TimeInterval(duration))
        onPhaseChanged?(newPhase, duration)
        onTick?(newPhase, duration)

        let nextTimer = Timer(timeInterval: 0.5, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(nextTimer, forMode: .common)
        timer = nextTimer
    }

    @objc private func tick() {
        guard let endDate else { return }

        let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        onTick?(phase, remaining)

        guard remaining == 0 else { return }

        switch phase {
        case .idle:
            stop()
        case .work:
            beginRest()
        case .rest:
            completeRest()
        case .restComplete:
            break
        }
    }

    private func completeRest() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        phase = .restComplete
        onPhaseChanged?(.restComplete, 0)
        onTick?(.restComplete, 0)
    }
}

private final class BreakOverlayController {
    private var windows: [BlockingWindow] = []
    private var overlayViews: [BreakOverlayView] = []
    var onActionSelected: ((OverlayAction) -> Void)?

    func show(duration: Int, videoSet: CatVideoSet?) {
        hide()

        for screen in NSScreen.screens {
            let window = BlockingWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.animationBehavior = .none
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]

            let overlayView = BreakOverlayView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                remaining: duration,
                videoSet: videoSet
            )
            overlayView.onActionSelected = { [weak self] action in
                self?.onActionSelected?(action)
            }
            window.contentView = overlayView
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            windows.append(window)
            overlayViews.append(overlayView)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func update(remaining: Int) {
        overlayViews.forEach { $0.remaining = remaining }
    }

    func showCompletionPrompt(videoSet: CatVideoSet?) {
        if overlayViews.isEmpty {
            show(duration: 0, videoSet: videoSet)
        }

        overlayViews.forEach {
            $0.remaining = 0
            $0.showPrompt(.restFinished)
        }
    }

    func hide() {
        windows.forEach {
            $0.orderOut(nil)
            $0.contentView = nil
        }
        overlayViews.removeAll()
        windows.removeAll()
    }
}

private final class BlockingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class OverlayPromptView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let buttons: [NSButton]
    private let options: [OverlayPromptOption]
    private let onAction: (OverlayAction) -> Void

    private let panelPadding: CGFloat = 18
    private let titleHeight: CGFloat = 30
    private let subtitleHeight: CGFloat = 22
    private let buttonHeight: CGFloat = 48
    private let buttonGap: CGFloat = 10
    private let headerGap: CGFloat = 18

    var preferredHeight: CGFloat {
        panelPadding * 2
            + titleHeight
            + subtitleHeight
            + headerGap
            + CGFloat(buttons.count) * buttonHeight
            + CGFloat(max(0, buttons.count - 1)) * buttonGap
    }

    override var isFlipped: Bool { true }

    init(kind: OverlayPromptKind, onAction: @escaping (OverlayAction) -> Void) {
        self.onAction = onAction
        self.options = kind.options
        self.buttons = kind.options.enumerated().map { index, option in
            let button = NSButton(title: option.title, target: nil, action: nil)
            button.tag = index
            return button
        }

        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.98, alpha: 0.74).cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.56).cgColor
        layer?.masksToBounds = true

        titleLabel.stringValue = kind.title
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.16, alpha: 0.95)
        addSubview(titleLabel)

        subtitleLabel.stringValue = kind.subtitle
        subtitleLabel.alignment = .center
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.22, alpha: 0.62)
        addSubview(subtitleLabel)

        for (index, button) in buttons.enumerated() {
            button.target = self
            button.action = #selector(buttonPressed)
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.alignment = .center
            button.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
            button.wantsLayer = true
            style(button, as: options[index].style)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let contentX = panelPadding
        let contentWidth = bounds.width - panelPadding * 2
        var y = panelPadding

        titleLabel.frame = CGRect(x: contentX, y: y, width: contentWidth, height: titleHeight)
        y += titleHeight
        subtitleLabel.frame = CGRect(x: contentX, y: y, width: contentWidth, height: subtitleHeight)
        y += subtitleHeight + headerGap

        for index in buttons.indices {
            buttons[index].frame = CGRect(x: contentX, y: y, width: contentWidth, height: buttonHeight)
            buttons[index].layer?.cornerRadius = 12
            y += buttonHeight + buttonGap
        }
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        guard let action = action(forButtonIndex: sender.tag) else { return }
        onAction(action)
    }

    func action(at point: CGPoint) -> OverlayAction? {
        for index in buttons.indices {
            if buttons[index].frame.contains(point) {
                return action(forButtonIndex: index)
            }
        }

        return nil
    }

    private func action(forButtonIndex index: Int) -> OverlayAction? {
        guard options.indices.contains(index) else { return nil }
        return options[index].action
    }

    private func style(_ button: NSButton, as style: OverlayButtonStyle) {
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.contentTintColor = NSColor(calibratedWhite: 0.14, alpha: 0.92)

        switch style {
        case .primary:
            button.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.92).cgColor
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.10).cgColor
        case .secondary:
            button.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.72).cgColor
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        case .destructive:
            button.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 0.58).cgColor
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        case .plain:
            button.contentTintColor = NSColor(calibratedWhite: 0.20, alpha: 0.72)
            button.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.34).cgColor
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
        }
    }
}

private final class BreakOverlayView: NSView {
    private var webView: WKWebView?
    private let closeButton = NSButton(title: "×", target: nil, action: nil)
    private var promptView: OverlayPromptView?
    var onActionSelected: ((OverlayAction) -> Void)?

    private var hasVideo: Bool {
        webView != nil
    }

    var remaining: Int {
        didSet {
            needsDisplay = true
            updateWebCountdown()
        }
    }

    init(frame frameRect: NSRect, remaining: Int, videoSet: CatVideoSet?) {
        self.remaining = remaining
        super.init(frame: frameRect)

        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        configureCloseButton()

        if let videoSet {
            configureVideo(set: videoSet)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func layout() {
        super.layout()
        webView?.frame = bounds
        layoutCloseButton()
        layoutPrompt()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }

    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let promptView {
            let promptPoint = promptView.convert(point, from: self)
            if let action = promptView.action(at: promptPoint) {
                handlePromptAction(action)
                return
            }
        }

        if closeButton.frame.contains(point) {
            showPrompt(.interruptRest)
        }
    }
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if !hasVideo {
            drawCatPlaceholder(in: videoFrame())
        }

        drawCountdown()
    }

    func showPrompt(_ kind: OverlayPromptKind) {
        promptView?.removeFromSuperview()

        let promptView = OverlayPromptView(kind: kind) { [weak self] action in
            self?.handlePromptAction(action)
        }

        addSubview(promptView)
        self.promptView = promptView
        layoutPrompt()
    }

    private func configureCloseButton() {
        closeButton.target = self
        closeButton.action = #selector(showInterruptPrompt)
        closeButton.isBordered = false
        closeButton.bezelStyle = .regularSquare
        closeButton.font = NSFont.systemFont(ofSize: 26, weight: .semibold)
        closeButton.contentTintColor = .white
        closeButton.toolTip = L10n.openRestOptions
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.38).cgColor
        closeButton.layer?.cornerRadius = 18
        closeButton.layer?.borderWidth = 1
        closeButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        addSubview(closeButton)
    }

    private func layoutCloseButton() {
        let size: CGFloat = 36
        let margin: CGFloat = 24
        closeButton.frame = CGRect(
            x: bounds.maxX - margin - size,
            y: bounds.maxY - margin - size,
            width: size,
            height: size
        )
    }

    private func layoutPrompt() {
        guard let promptView else { return }

        let panelWidth = min(max(bounds.width * 0.30, 360), 460)
        let panelHeight = promptView.preferredHeight
        promptView.frame = CGRect(
            x: bounds.midX - panelWidth / 2,
            y: bounds.midY - panelHeight / 2 - bounds.height * 0.02,
            width: panelWidth,
            height: panelHeight
        )
    }

    @objc private func showInterruptPrompt() {
        showPrompt(.interruptRest)
    }

    private func handlePromptAction(_ action: OverlayAction) {
        switch action {
        case .cancel:
            promptView?.removeFromSuperview()
            promptView = nil
        case .delayRest:
            promptView?.removeFromSuperview()
            promptView = nil
            onActionSelected?(action)
        case .continuePomodoro, .endPomodoro:
            onActionSelected?(action)
        }
    }

    private func configureVideo(set: CatVideoSet) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = false

        let webView = WKWebView(frame: bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.isHidden = false
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.isOpaque = false
        webView.layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(webView, positioned: .below, relativeTo: closeButton)
        self.webView = webView

        webView.loadHTMLString(videoHTML(for: set), baseURL: set.introURL.deletingLastPathComponent())
    }

    private func updateWebCountdown() {
        let script = "window.setRemaining && window.setRemaining(\(remaining));"
        webView?.evaluateJavaScript(script)
    }

    private func videoFrame() -> CGRect {
        let width = min(max(bounds.width * 0.48, 320), 760)
        let height = min(max(width * 0.56, 220), bounds.height * 0.48)
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2 + bounds.height * 0.04,
            width: width,
            height: height
        )
    }

    private func videoHTML(for set: CatVideoSet) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html, body {
            width: 100%;
            height: 100%;
            margin: 0;
            overflow: hidden;
            background: transparent;
        }
        canvas {
            position: fixed;
            inset: 0;
            width: 100vw;
            height: 100vh;
            background: transparent;
            pointer-events: none;
        }
        video {
            position: fixed;
            width: 1px;
            height: 1px;
            opacity: 0;
            pointer-events: none;
        }
        #countdown {
            position: fixed;
            left: 0;
            right: 0;
            bottom: 72px;
            color: rgba(255, 255, 255, 0.94);
            font: 600 34px ui-monospace, SFMono-Regular, Menlo, monospace;
            text-align: center;
            text-shadow: 0 1px 8px rgba(0, 0, 0, 0.55);
            pointer-events: none;
        }
        </style>
        </head>
        <body>
        <canvas id="catCanvas"></canvas>
        <video id="cat" autoplay muted playsinline preload="auto"></video>
        <div id="countdown"></div>
        <script>
        const introUrl = \(javaScriptString(set.introURL.absoluteString));
        const loopUrl = \(javaScriptString(set.loopURL.absoluteString));
        const restLabel = \(javaScriptString(L10n.rest));
        const initialRemaining = \(remaining);
        const video = document.getElementById('cat');
        const canvas = document.getElementById('catCanvas');
        const countdown = document.getElementById('countdown');
        const ctx = canvas.getContext('2d', { alpha: true });
        const source = document.createElement('canvas');
        const sourceCtx = source.getContext('2d', { alpha: true, willReadFrequently: true });
        const maximumCanvasScale = 1.25;
        const maximumProcessWidth = 760;
        const targetFrameInterval = 1 / 30;
        let introDone = false;
        let frameScheduled = false;
        let forceNextFrame = true;
        let lastRenderedMediaTime = -Infinity;
        let alphaMode = 'unknown';
        let alphaProbeFrames = 0;
        let matteState = new Uint8Array(0);
        let matteQueue = new Int32Array(0);

        function formatTime(seconds) {
            const safeSeconds = Math.max(0, Math.floor(seconds));
            const minutes = String(Math.floor(safeSeconds / 60)).padStart(2, '0');
            const remainder = String(safeSeconds % 60).padStart(2, '0');
            return `${minutes}:${remainder}`;
        }

        window.setRemaining = function(seconds) {
            countdown.textContent = `${restLabel} ${formatTime(seconds)}`;
        };

        function resizeCanvas() {
            const scale = Math.min(window.devicePixelRatio || 1, maximumCanvasScale);
            canvas.width = Math.max(1, Math.round(window.innerWidth * scale));
            canvas.height = Math.max(1, Math.round(window.innerHeight * scale));
            forceNextFrame = true;
        }

        function containRect(contentWidth, contentHeight, boxWidth, boxHeight) {
            const scale = Math.min(boxWidth / contentWidth, boxHeight / contentHeight);
            const width = contentWidth * scale;
            const height = contentHeight * scale;
            return {
                x: (boxWidth - width) / 2,
                y: (boxHeight - height) / 2,
                width,
                height
            };
        }

        function clamp(value, lower, upper) {
            return Math.min(upper, Math.max(lower, value));
        }

        function ensureMatte(pixelCount) {
            if (matteState.length !== pixelCount) {
                matteState = new Uint8Array(pixelCount);
                matteQueue = new Int32Array(pixelCount);
            } else {
                matteState.fill(0, 0, pixelCount);
            }
        }

        function whiteBackgroundScore(data, offset) {
            const red = data[offset];
            const green = data[offset + 1];
            const blue = data[offset + 2];
            const max = Math.max(red, green, blue);
            const min = Math.min(red, green, blue);
            const luma = red * 0.299 + green * 0.587 + blue * 0.114;
            const spread = max - min;
            const spreadLimit = luma > 244 ? 64 : 52;

            if (min < 210 || luma < 218 || spread > spreadLimit) {
                return 0;
            }

            const redDistance = 255 - red;
            const greenDistance = 255 - green;
            const blueDistance = 255 - blue;
            const whiteDistanceSquared = redDistance * redDistance + greenDistance * greenDistance + blueDistance * blueDistance;
            const maximumWhiteDistanceSquared = 92 * 92;
            if (whiteDistanceSquared > maximumWhiteDistanceSquared) {
                return 0;
            }

            const lumaScore = clamp((luma - 218) / 30, 0, 1);
            const minScore = clamp((min - 210) / 34, 0, 1);
            const distanceScore = clamp((maximumWhiteDistanceSquared - whiteDistanceSquared) / maximumWhiteDistanceSquared, 0, 1);
            const neutralScore = clamp((spreadLimit - spread) / spreadLimit, 0, 1);
            return clamp(lumaScore * 0.38 + minScore * 0.34 + distanceScore * 0.18 + neutralScore * 0.10, 0, 1);
        }

        function classifyWhiteBackground(data, pixelIndex) {
            const current = matteState[pixelIndex];
            if (current !== 0) {
                return current === 1;
            }

            if (whiteBackgroundScore(data, pixelIndex * 4) >= 0.16) {
                matteState[pixelIndex] = 1;
                return true;
            }

            matteState[pixelIndex] = 2;
            return false;
        }

        function applyAlphaFallback(imageData, width, height) {
            const data = imageData.data;

            if (alphaMode !== 'opaque') {
                let hasAlpha = false;
                for (let index = 3; index < data.length; index += 4) {
                    if (data[index] < 250) {
                        hasAlpha = true;
                        break;
                    }
                }

                if (hasAlpha) {
                    alphaMode = 'native';
                    return;
                }

                alphaProbeFrames += 1;
                if (alphaProbeFrames >= 6) {
                    alphaMode = 'opaque';
                }
            }

            if (alphaMode === 'native') {
                return;
            }

            const pixelCount = width * height;
            ensureMatte(pixelCount);

            let head = 0;
            let tail = 0;

            function enqueue(pixelIndex) {
                if (matteState[pixelIndex] === 0 && classifyWhiteBackground(data, pixelIndex)) {
                    matteQueue[tail] = pixelIndex;
                    tail += 1;
                }
            }

            for (let x = 0; x < width; x += 1) {
                enqueue(x);
                enqueue((height - 1) * width + x);
            }

            for (let y = 1; y < height - 1; y += 1) {
                enqueue(y * width);
                enqueue(y * width + width - 1);
            }

            while (head < tail) {
                const pixelIndex = matteQueue[head];
                head += 1;
                const x = pixelIndex % width;
                const y = (pixelIndex - x) / width;

                if (x > 0) {
                    enqueue(pixelIndex - 1);
                }
                if (x < width - 1) {
                    enqueue(pixelIndex + 1);
                }
                if (y > 0) {
                    enqueue(pixelIndex - width);
                }
                if (y < height - 1) {
                    enqueue(pixelIndex + width);
                }
            }

            for (let pixelIndex = 0; pixelIndex < pixelCount; pixelIndex += 1) {
                if (matteState[pixelIndex] === 1) {
                    data[pixelIndex * 4 + 3] = 0;
                }
            }

            for (let y = 1; y < height - 1; y += 1) {
                for (let x = 1; x < width - 1; x += 1) {
                    const pixelIndex = y * width + x;
                    if (matteState[pixelIndex] === 1) {
                        continue;
                    }

                    const hasBackgroundNeighbor =
                        matteState[pixelIndex - 1] === 1 ||
                        matteState[pixelIndex + 1] === 1 ||
                        matteState[pixelIndex - width] === 1 ||
                        matteState[pixelIndex + width] === 1;

                    if (!hasBackgroundNeighbor) {
                        continue;
                    }

                    const offset = pixelIndex * 4;
                    const score = whiteBackgroundScore(data, offset);
                    if (score <= 0.10) {
                        continue;
                    }

                    const keyAmount = clamp((score - 0.10) / 0.58, 0, 0.88);
                    data[offset + 3] = Math.min(data[offset + 3], Math.round(255 * (1 - keyAmount)));
                }
            }
        }

        function renderFrame(now, metadata) {
            frameScheduled = false;

            if (!video.videoWidth || !video.videoHeight) {
                scheduleFrame();
                return;
            }

            const mediaTime = metadata && Number.isFinite(metadata.mediaTime) ? metadata.mediaTime : video.currentTime;
            if (!forceNextFrame && mediaTime >= lastRenderedMediaTime && mediaTime - lastRenderedMediaTime < targetFrameInterval) {
                scheduleFrame();
                return;
            }
            forceNextFrame = false;
            lastRenderedMediaTime = mediaTime;

            const processScale = Math.min(1, maximumProcessWidth / video.videoWidth);
            const processWidth = Math.max(1, Math.round(video.videoWidth * processScale));
            const processHeight = Math.max(1, Math.round(video.videoHeight * processScale));

            if (source.width !== processWidth || source.height !== processHeight) {
                source.width = processWidth;
                source.height = processHeight;
            }

            sourceCtx.clearRect(0, 0, processWidth, processHeight);
            sourceCtx.drawImage(video, 0, 0, processWidth, processHeight);

            try {
                const imageData = sourceCtx.getImageData(0, 0, processWidth, processHeight);
                applyAlphaFallback(imageData, processWidth, processHeight);
                sourceCtx.putImageData(imageData, 0, 0);

                ctx.clearRect(0, 0, canvas.width, canvas.height);
                const rect = containRect(processWidth, processHeight, canvas.width, canvas.height);
                ctx.drawImage(source, rect.x, rect.y, rect.width, rect.height);
            } catch (error) {
                video.style.opacity = '1';
                video.style.width = '100vw';
                video.style.height = '100vh';
                video.style.objectFit = 'contain';
                canvas.style.display = 'none';
            }

            scheduleFrame();
        }

        function scheduleFrame() {
            if (frameScheduled) {
                return;
            }

            frameScheduled = true;
            if (video.requestVideoFrameCallback) {
                video.requestVideoFrameCallback(renderFrame);
            } else {
                requestAnimationFrame(renderFrame);
            }
        }

        video.src = introUrl;
        video.addEventListener('ended', () => {
            if (!introDone) {
                introDone = true;
                video.loop = true;
                video.src = loopUrl;
                forceNextFrame = true;
                lastRenderedMediaTime = -Infinity;
                alphaMode = 'unknown';
                alphaProbeFrames = 0;
                video.play();
            }
        });
        video.addEventListener('loadedmetadata', scheduleFrame);
        video.addEventListener('play', scheduleFrame);
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();
        window.setRemaining(initialRemaining);
        video.play();
        </script>
        </body>
        </html>
        """
    }

    private func javaScriptString(_ value: String) -> String {
        var result = "\""
        for character in value {
            switch character {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            default:
                result.append(character)
            }
        }
        result += "\""
        return result
    }

    private func drawCountdown() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = CGSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)

        let text = "\(L10n.rest) \(formatTime(remaining))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.94),
            .paragraphStyle: paragraph,
            .shadow: shadow
        ]

        let rect = CGRect(x: 0, y: bounds.minY + 72, width: bounds.width, height: 48)
        text.draw(in: rect, withAttributes: attributes)
    }

    private func drawCatPlaceholder(in frame: CGRect) {
        let bodyRect = CGRect(
            x: frame.midX - frame.width * 0.22,
            y: frame.midY - frame.height * 0.08,
            width: frame.width * 0.44,
            height: frame.height * 0.24
        )
        let headRect = CGRect(
            x: bodyRect.maxX - bodyRect.height * 0.35,
            y: bodyRect.maxY - bodyRect.height * 0.55,
            width: bodyRect.height * 0.72,
            height: bodyRect.height * 0.72
        )

        NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 0.82).setFill()

        let body = NSBezierPath(roundedRect: bodyRect, xRadius: bodyRect.height * 0.5, yRadius: bodyRect.height * 0.5)
        body.fill()

        let head = NSBezierPath(ovalIn: headRect)
        head.fill()

        let leftEar = NSBezierPath()
        leftEar.move(to: CGPoint(x: headRect.minX + headRect.width * 0.18, y: headRect.maxY - 2))
        leftEar.line(to: CGPoint(x: headRect.minX + headRect.width * 0.34, y: headRect.maxY + headRect.height * 0.28))
        leftEar.line(to: CGPoint(x: headRect.minX + headRect.width * 0.48, y: headRect.maxY - 2))
        leftEar.close()
        leftEar.fill()

        let rightEar = NSBezierPath()
        rightEar.move(to: CGPoint(x: headRect.maxX - headRect.width * 0.48, y: headRect.maxY - 2))
        rightEar.line(to: CGPoint(x: headRect.maxX - headRect.width * 0.34, y: headRect.maxY + headRect.height * 0.28))
        rightEar.line(to: CGPoint(x: headRect.maxX - headRect.width * 0.18, y: headRect.maxY - 2))
        rightEar.close()
        rightEar.fill()

        let tail = NSBezierPath()
        tail.lineWidth = max(8, bodyRect.height * 0.14)
        tail.lineCapStyle = .round
        tail.move(to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.08, y: bodyRect.midY + 2))
        tail.curve(
            to: CGPoint(x: bodyRect.minX - bodyRect.width * 0.22, y: bodyRect.midY + bodyRect.height * 0.34),
            controlPoint1: CGPoint(x: bodyRect.minX - bodyRect.width * 0.12, y: bodyRect.midY + bodyRect.height * 0.15),
            controlPoint2: CGPoint(x: bodyRect.minX - bodyRect.width * 0.20, y: bodyRect.midY + bodyRect.height * 0.46)
        )
        tail.stroke()

        NSColor.white.withAlphaComponent(0.88).setFill()
        NSBezierPath(ovalIn: CGRect(x: headRect.midX + 2, y: headRect.midY + 2, width: 4, height: 4)).fill()
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let timer = PomodoroTimer()
    private let overlay = BreakOverlayController()

    private lazy var primaryItem = NSMenuItem(title: L10n.start, action: #selector(toggleStartStop), keyEquivalent: "s")
    private lazy var workDurationItem = NSMenuItem(title: "", action: #selector(changeWorkDuration), keyEquivalent: "")
    private lazy var restDurationItem = NSMenuItem(title: "", action: #selector(changeRestDuration), keyEquivalent: "")
    private lazy var launchAtLoginItem = NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private lazy var aboutItem = NSMenuItem(title: L10n.aboutCatRest, action: #selector(showAbout), keyEquivalent: "")
    private lazy var quitItem = NSMenuItem(title: L10n.quitCatRest, action: #selector(quit), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureTimer()
        updateMenu()
        updateStatus(phase: .idle, remaining: 0)

        if RuntimeOptions.autoStart {
            timer.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay.hide()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    private func configureStatusItem() {
        statusItem.button?.title = ""
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        configureStatusIcon()
        configureAppIcon()

        menu.delegate = self
        primaryItem.target = self
        primaryItem.keyEquivalentModifierMask = [.command]
        workDurationItem.target = self
        restDurationItem.target = self
        launchAtLoginItem.target = self
        aboutItem.target = self
        quitItem.target = self

        menu.addItem(primaryItem)
        menu.addItem(.separator())
        menu.addItem(workDurationItem)
        menu.addItem(restDurationItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func configureStatusIcon() {
        guard let image = IconAssets.statusBarImage() else { return }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true

        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
    }

    private func configureAppIcon() {
        guard let image = IconAssets.appIconImage(size: NSSize(width: 128, height: 128)) else { return }
        NSApp.applicationIconImage = image
    }

    private func configureTimer() {
        overlay.onActionSelected = { [weak self] action in
            guard let self else { return }

            switch action {
            case .continuePomodoro:
                self.timer.continuePomodoro()
            case .delayRest:
                self.timer.delayRest(by: 60)
            case .endPomodoro:
                self.timer.stop()
            case .cancel:
                break
            }

            self.updateMenu()
        }

        timer.onPhaseChanged = { [weak self] phase, remaining in
            guard let self else { return }

            switch phase {
            case .rest:
                self.overlay.show(duration: remaining, videoSet: CatVideoSet.discover())
            case .restComplete:
                self.overlay.showCompletionPrompt(videoSet: CatVideoSet.discover())
                self.scheduleAutoContinueIfNeeded()
            case .idle, .work:
                self.overlay.hide()
            }

            self.updateStatus(phase: phase, remaining: remaining)
            self.updateMenu()
        }

        timer.onTick = { [weak self] phase, remaining in
            guard let self else { return }
            if phase == .rest {
                self.overlay.update(remaining: remaining)
            }
            self.updateStatus(phase: phase, remaining: remaining)
        }
    }

    private func updateStatus(phase: Phase, remaining: Int) {
        statusItem.button?.title = ""

        switch phase {
        case .idle:
            statusItem.button?.toolTip = L10n.idle
        case .work:
            statusItem.button?.toolTip = "\(L10n.work) \(formatTime(remaining))"
        case .rest:
            statusItem.button?.toolTip = "\(L10n.rest) \(formatTime(remaining))"
        case .restComplete:
            statusItem.button?.toolTip = L10n.restDone
        }
    }

    private func updateMenu() {
        primaryItem.title = timer.isRunning ? L10n.stop : L10n.start
        workDurationItem.title = L10n.workDurationMenu(minutes: Settings.workSeconds / 60)
        restDurationItem.title = L10n.restDurationMenu(minutes: Settings.restSeconds / 60)
        launchAtLoginItem.state = launchAtLoginState()
        launchAtLoginItem.title = launchAtLoginTitle()
        aboutItem.title = L10n.aboutCatRest
        quitItem.title = L10n.quitCatRest

        let canConfigure = !timer.isRunning
        workDurationItem.isEnabled = canConfigure
        restDurationItem.isEnabled = canConfigure
    }

    private func launchAtLoginState() -> NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        case .notRegistered, .notFound:
            return .off
        @unknown default:
            return .off
        }
    }

    private func launchAtLoginTitle() -> String {
        if SMAppService.mainApp.status == .requiresApproval {
            return L10n.launchAtLoginRequiresApproval
        }

        return L10n.launchAtLogin
    }

    private func scheduleAutoContinueIfNeeded() {
        guard RuntimeOptions.autoContinueAfterRest else { return }

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self, self.timer.phase == .restComplete else { return }
            self.timer.continuePomodoro()
        }
    }

    @objc private func toggleStartStop() {
        if timer.isRunning {
            timer.stop()
        } else {
            timer.start()
        }
        updateMenu()
    }

    @objc private func changeWorkDuration() {
        promptForMinutes(title: L10n.workDurationTitle, currentSeconds: Settings.workSeconds) { seconds in
            Settings.workSeconds = seconds
            self.updateMenu()
        }
    }

    @objc private func changeRestDuration() {
        promptForMinutes(title: L10n.restDurationTitle, currentSeconds: Settings.restSeconds) { seconds in
            Settings.restSeconds = seconds
            self.updateMenu()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError(title: L10n.unableToUpdateLaunchAtLogin, message: error.localizedDescription)
        }

        updateMenu()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)

        let urlString = "https://x.com/cyberpigeonb"
        let alert = NSAlert()
        alert.messageText = "CatRest"
        alert.informativeText = "\(L10n.authorInfo)\n\(urlString)"
        if let icon = IconAssets.appIconImage(size: NSSize(width: 64, height: 64)) {
            alert.icon = icon
        }
        alert.addButton(withTitle: L10n.openAuthorPage)
        alert.addButton(withTitle: L10n.close)

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L10n.ok)
        alert.runModal()
    }

    private func promptForMinutes(title: String, currentSeconds: Int, completion: (Int) -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = String(currentSeconds / 60)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = L10n.durationPrompt
        alert.accessoryView = input
        alert.addButton(withTitle: L10n.save)
        alert.addButton(withTitle: L10n.cancel)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let minutes = Double(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)), minutes > 0 else { return }

        let seconds = Int((minutes * 60).rounded())
        completion(seconds)
    }
}

private func formatTime(_ seconds: Int) -> String {
    let safeSeconds = max(0, seconds)
    return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
