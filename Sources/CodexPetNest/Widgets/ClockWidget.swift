import AppKit

final class ClockWidget: NSView {
    private let timeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .medium)
        timeLabel.alignment = .center
        timeLabel.textColor = .white
        timeLabel.drawsBackground = false
        addSubview(timeLabel)

        dateLabel.font = .systemFont(ofSize: 10, weight: .regular)
        dateLabel.alignment = .center
        dateLabel.textColor = .white.withAlphaComponent(0.7)
        dateLabel.drawsBackground = false
        addSubview(dateLabel)

        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height
        timeLabel.frame = NSRect(x: 0, y: h - 28, width: bounds.width, height: 24)
        dateLabel.frame = NSRect(x: 0, y: 4, width: bounds.width, height: 14)
    }

    private func update() {
        let now = Date()
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        timeLabel.stringValue = tf.string(from: now)
        let df = DateFormatter()
        df.dateFormat = "MM/dd EEE"
        dateLabel.stringValue = df.string(from: now)
    }
}
