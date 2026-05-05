import AppKit

final class CountdownWidget: NSView {
    private let label = NSTextField(labelWithString: "")
    private let setButton = NSButton(title: "Set", target: nil, action: nil)
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        label.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        label.alignment = .center
        label.textColor = .white
        label.drawsBackground = false
        label.stringValue = "--:--:--"
        addSubview(label)

        setButton.font = .systemFont(ofSize: 10)
        setButton.bezelStyle = .inline
        setButton.isBordered = false
        setButton.contentTintColor = .white.withAlphaComponent(0.8)
        setButton.target = self
        setButton.action = #selector(openPicker)
        addSubview(setButton)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height
        label.frame = NSRect(x: 0, y: h - 26, width: bounds.width, height: 22)
        setButton.frame = NSRect(x: 0, y: 2, width: bounds.width, height: 16)
    }

    private func targetDate() -> Date? {
        guard let s = SettingsStore.shared.settings.countdownTarget,
              let d = ISO8601DateFormatter().date(from: s) else { return nil }
        return d
    }

    private func update() {
        guard let target = targetDate() else {
            label.stringValue = "--:--:--"
            return
        }
        let remain = target.timeIntervalSinceNow
        if remain <= 0 {
            label.stringValue = "00:00:00"
            return
        }
        let h = Int(remain) / 3600
        let m = (Int(remain) % 3600) / 60
        let s = Int(remain) % 60
        label.stringValue = String(format: "%02d:%02d:%02d", h, m, s)
    }

    @objc private func openPicker() {
        let vc = CountdownPickerViewController()
        let popover = NSPopover()
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.show(relativeTo: setButton.bounds, of: setButton, preferredEdge: .maxY)
    }
}

final class CountdownPickerViewController: NSViewController {
    private let picker = NSDatePicker()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        picker.datePickerStyle = .textFieldAndStepper
        picker.presentsCalendarOverlay = true
        picker.minDate = Date()
        picker.frame = NSRect(x: 20, y: 140, width: 160, height: 24)
        if let t = target() { picker.dateValue = t }
        view.addSubview(picker)

        let done = NSButton(title: "Set Countdown", target: self, action: #selector(commit))
        done.frame = NSRect(x: 20, y: 100, width: 160, height: 24)
        view.addSubview(done)
    }

    private func target() -> Date? {
        guard let s = SettingsStore.shared.settings.countdownTarget,
              let d = ISO8601DateFormatter().date(from: s) else { return nil }
        return d
    }

    @objc private func commit() {
        let iso = ISO8601DateFormatter().string(from: picker.dateValue)
        SettingsStore.shared.settings.countdownTarget = iso
        SettingsStore.shared.save()
        dismiss(nil)
    }
}
