import AppKit

enum NestUI {
    static let radius: CGFloat = 8
    static let smallRadius: CGFloat = 6

    static func panel(_ view: NSView, color: NSColor = .controlBackgroundColor) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = color.cgColor
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        view.layer?.borderWidth = 1
    }

    static func previewSurface(_ view: NSView) {
        panel(view, color: NSColor(calibratedRed: 0.94, green: 0.98, blue: 0.97, alpha: 1))
    }

    static func badge(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = color
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.wantsLayer = true
        label.layer?.cornerRadius = smallRadius
        label.layer?.backgroundColor = color.withAlphaComponent(0.12).cgColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    static func stylePrimaryButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.contentTintColor = .systemTeal
    }

    static func styleSecondaryButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .regular
    }

    static func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
    }
}
