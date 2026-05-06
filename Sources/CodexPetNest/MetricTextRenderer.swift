import AppKit

final class MetricTextRenderer: NSView, NestElementRenderer {
    private let label = NSTextField(labelWithString: "")
    private let element: MetricTextElement
    
    override var isFlipped: Bool { true }
    
    init(element: MetricTextElement) {
        self.element = element
        super.init(frame: .zero)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        applyStyle()
    }
    
    private func applyStyle() {
        let style = element.style
        
        // Font size and weight
        let fontSize = CGFloat(style?.fontSize ?? 11)
        let weight: NSFont.Weight
        switch style?.fontWeight {
        case "medium": weight = .medium
        case "semibold": weight = .semibold
        case "bold": weight = .bold
        default: weight = .regular
        }
        label.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        
        // Color
        if let hex = style?.color {
            label.textColor = NSColor.fromHex(hex) ?? .white
        } else {
            label.textColor = .white
        }
        
        // Alignment
        switch style?.alignment {
        case "left": label.alignment = .left
        case "right": label.alignment = .right
        default: label.alignment = .center
        }
    }
    
    func update(snapshot: MetricSnapshot) {
        let value = snapshot.value(for: element.metric)
        let style = element.style
        
        var displayText: String = ""
        
        switch value {
        case .percent(let d):
            displayText = String(format: "%.0f", d)
        case .ratio(let d):
            displayText = String(format: "%.0f", d * 100)
        case .text(let s), .enumeration(let s):
            displayText = s
        case .number(let d):
            displayText = String(format: "%.0f", d)
        case .boolean(let b):
            displayText = b ? "true" : "false"
        case .unavailable:
            displayText = style?.fallbackText ?? ""
        }
        
        if !displayText.isEmpty {
            let prefix = style?.prefix ?? ""
            let suffix = style?.suffix ?? ""
            
            // Avoid double percent if suffix is "%" and we already have it (though our formatting here doesn't add it)
            // But wait, the prompt said: "percent: 无小数，如果 suffix 是 "%"，注意不要输出双百分号。建议 value 文本只输出数字，suffix 控制符号。"
            // So we output just the number.
            
            label.stringValue = "\(prefix)\(displayText)\(suffix)"
        } else {
            label.stringValue = ""
        }
    }
}

// Simple Hex extension if not exists
extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat((rgb & 0x0000FF)) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat((rgb & 0x000000FF)) / 255.0
        } else {
            return nil
        }
        
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
