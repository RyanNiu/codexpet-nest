import AppKit

final class NestRenderer: NSView {
    private var clockWidget: ClockWidget?
    private var countdownWidget: CountdownWidget?
    private var pomodoroWidget: PomodoroWidget?
    private let cornerRadius: CGFloat = 16

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.82).cgColor
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        rebuildWidgets()
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let widgets = [clockWidget, countdownWidget, pomodoroWidget].compactMap { $0 }
        guard !widgets.isEmpty else { return }
        let w = bounds.width / CGFloat(widgets.count)
        let h = bounds.height
        for (i, widget) in widgets.enumerated() {
            widget.frame = NSRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
        }
    }

    func rebuildWidgets() {
        clockWidget?.removeFromSuperview()
        countdownWidget?.removeFromSuperview()
        pomodoroWidget?.removeFromSuperview()

        if SettingsStore.shared.widgetEnabled("clock") {
            clockWidget = ClockWidget(frame: .zero)
            addSubview(clockWidget!)
        }
        if SettingsStore.shared.widgetEnabled("countdown") {
            countdownWidget = CountdownWidget(frame: .zero)
            addSubview(countdownWidget!)
        }
        if SettingsStore.shared.widgetEnabled("pomodoro") {
            pomodoroWidget = PomodoroWidget(frame: .zero)
            addSubview(pomodoroWidget!)
        }
        needsLayout = true
    }

    @objc private func settingsChanged() {
        rebuildWidgets()
    }
}
