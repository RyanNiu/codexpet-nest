import AppKit

enum PomodoroPhase {
    case idle
    case focus
    case rest
    case paused
}

final class PomodoroWidget: NSView {
    private let timeLabel = NSTextField(labelWithString: "")
    private let phaseLabel = NSTextField(labelWithString: "")
    private let startPauseButton = NSButton(title: "Start", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private var timer: Timer?
    private var phase: PomodoroPhase = .idle
    private var secondsRemaining: Int = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        timeLabel.alignment = .center
        timeLabel.textColor = .white
        timeLabel.drawsBackground = false
        timeLabel.stringValue = "25:00"
        addSubview(timeLabel)

        phaseLabel.font = .systemFont(ofSize: 9, weight: .regular)
        phaseLabel.alignment = .center
        phaseLabel.textColor = .white.withAlphaComponent(0.6)
        phaseLabel.drawsBackground = false
        phaseLabel.stringValue = "Ready"
        addSubview(phaseLabel)

        startPauseButton.font = .systemFont(ofSize: 10)
        startPauseButton.bezelStyle = .inline
        startPauseButton.isBordered = false
        startPauseButton.contentTintColor = .white.withAlphaComponent(0.8)
        startPauseButton.target = self
        startPauseButton.action = #selector(toggleStartPause)
        addSubview(startPauseButton)

        resetButton.font = .systemFont(ofSize: 10)
        resetButton.bezelStyle = .inline
        resetButton.isBordered = false
        resetButton.contentTintColor = .white.withAlphaComponent(0.5)
        resetButton.target = self
        resetButton.action = #selector(doReset)
        addSubview(resetButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        timeLabel.frame = NSRect(x: 0, y: h - 26, width: w, height: 22)
        phaseLabel.frame = NSRect(x: 0, y: h - 34, width: w, height: 10)
        let btnW = (w - 4) / 2
        startPauseButton.frame = NSRect(x: 0, y: 0, width: btnW, height: 16)
        resetButton.frame = NSRect(x: btnW + 4, y: 0, width: btnW, height: 16)
    }

    @objc private func toggleStartPause() {
        switch phase {
        case .idle, .paused:
            startOrResume()
        case .focus, .rest:
            pause()
        }
    }

    @objc private func doReset() {
        phase = .idle
        secondsRemaining = SettingsStore.shared.settings.pomodoro.focusMinutes * 60
        updateDisplay()
        timer?.invalidate()
        timer = nil
    }

    private func startOrResume() {
        if phase == .idle || phase == .paused && phase != .focus && phase != .rest {
            phase = .focus
            secondsRemaining = SettingsStore.shared.settings.pomodoro.focusMinutes * 60
        } else if phase == .paused {
            // resume existing
            phase = secondsRemaining > 0 ? .focus : .rest
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        updateDisplay()
    }

    private func pause() {
        phase = .paused
        updateDisplay()
    }

    private func tick() {
        secondsRemaining -= 1
        if secondsRemaining <= 0 {
            if phase == .focus {
                phase = .rest
                secondsRemaining = SettingsStore.shared.settings.pomodoro.breakMinutes * 60
            } else {
                phase = .idle
                secondsRemaining = SettingsStore.shared.settings.pomodoro.focusMinutes * 60
                timer?.invalidate()
                timer = nil
            }
        }
        updateDisplay()
    }

    private func updateDisplay() {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        timeLabel.stringValue = String(format: "%02d:%02d", m, s)
        switch phase {
        case .idle:   phaseLabel.stringValue = "Ready"
        case .focus:  phaseLabel.stringValue = "Focus"
        case .rest:   phaseLabel.stringValue = "Break"
        case .paused: phaseLabel.stringValue = "Paused"
        }
        switch phase {
        case .idle, .paused:
            startPauseButton.title = "Start"
        case .focus, .rest:
            startPauseButton.title = "Pause"
        }
    }
}
