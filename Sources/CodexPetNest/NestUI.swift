import AppKit

enum NestUI {
    static let radius: CGFloat = 10
    static let smallRadius: CGFloat = 6

    // MARK: - Semantic Colors
    
    static var appBackground: NSColor {
        .windowBackgroundColor
    }
    
    static var sidebarBackground: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
                ? NSColor(calibratedWhite: 0.14, alpha: 1.0)
                : NSColor(calibratedWhite: 0.96, alpha: 1.0)
        }
    }
    
    static var contentBackground: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
                ? NSColor(calibratedWhite: 0.11, alpha: 1.0)
                : .white
        }
    }
    
    static var panelBackground: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
                ? NSColor(calibratedWhite: 0.16, alpha: 1.0)
                : NSColor(calibratedWhite: 0.98, alpha: 1.0)
        }
    }
    
    static var selectedRowBackground: NSColor {
        NSColor.systemTeal.withAlphaComponent(0.15)
    }
    
    static var previewBackground: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
                ? NSColor(calibratedWhite: 0.08, alpha: 1.0)
                : NSColor(calibratedRed: 0.94, green: 0.98, blue: 0.97, alpha: 1)
        }
    }
    
    static var hairline: NSColor {
        NSColor.separatorColor.withAlphaComponent(0.3)
    }
    
    static var mutedText: NSColor {
        .secondaryLabelColor
    }
    
    static var accent: NSColor {
        .systemTeal
    }
    
    static var controlFill: NSColor {
        NSColor.controlTextColor.withAlphaComponent(0.05)
    }

    // MARK: - UI Helpers
    
    static func panel(_ view: NSView, color: NSColor = .controlBackgroundColor, radius: CGFloat = radius) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = color.cgColor
        // Default panel no longer has border for cleaner look
        view.layer?.borderWidth = 0
    }
    
    static func hairlinePanel(_ view: NSView, color: NSColor = .clear) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = color.cgColor
        view.layer?.borderColor = hairline.cgColor
        view.layer?.borderWidth = 1
    }

    static func previewSurface(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = previewBackground.cgColor
        // Subtle shadow or inner glow instead of hard border
        view.layer?.borderWidth = 0
    }

    static func badge(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = color
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.layer?.backgroundColor = color.withAlphaComponent(0.12).cgColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    static func stylePrimaryButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = accent.cgColor
        button.layer?.cornerRadius = 6
        
        let title = button.attributedTitle.mutableCopy() as? NSMutableAttributedString ?? NSMutableAttributedString(string: button.title)
        title.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: title.length))
        title.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .medium), range: NSRange(location: 0, length: title.length))
        button.attributedTitle = title
    }

    static func styleSecondaryButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = controlFill.cgColor
        button.layer?.cornerRadius = 6
        
        let title = button.attributedTitle.mutableCopy() as? NSMutableAttributedString ?? NSMutableAttributedString(string: button.title)
        title.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: title.length))
        title.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .regular), range: NSRange(location: 0, length: title.length))
        button.attributedTitle = title
    }

    static func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
    }
}

