import AppKit

struct PetBounds: Equatable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var center: NSPoint {
        NSPoint(x: x + width / 2, y: y + height / 2)
    }
}

enum PetReadResult {
    case unavailable
    case closed
    case open(bounds: PetBounds)
}

private func cgFloat(from dict: [String: Any], key: String) -> CGFloat? {
    guard let d = dict[key] as? Double else { return nil }
    return CGFloat(d)
}

final class PetPositionReader {
    private let stateURL: URL

    init() {
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex").path
        stateURL = URL(fileURLWithPath: codexHome)
            .appendingPathComponent(".codex-global-state.json")
    }

    func read() -> PetReadResult {
        guard let data = try? Data(contentsOf: stateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .unavailable
        }

        let isOpen = json["electron-avatar-overlay-open"] as? Bool ?? false

        guard isOpen,
              let bounds = json["electron-avatar-overlay-bounds"] as? [String: Any],
              let mascot = bounds["mascot"] as? [String: Any],
              let bx = cgFloat(from: bounds, key: "x"),
              let by = cgFloat(from: bounds, key: "y"),
              let ml = cgFloat(from: mascot, key: "left"),
              let mt = cgFloat(from: mascot, key: "top"),
              let mw = cgFloat(from: mascot, key: "width"),
              let mh = cgFloat(from: mascot, key: "height")
        else {
            return .closed
        }

        let petBounds = PetBounds(
            x: bx + ml,
            y: by + mt,
            width: mw,
            height: mh
        )

        return .open(bounds: petBounds)
    }
}

func screenForTopLeftRect(_ tlRect: NSRect) -> NSScreen? {
    let center = NSPoint(x: tlRect.midX, y: tlRect.midY)
    for screen in NSScreen.screens {
        let sf = screen.frame
        if sf.contains(center) {
            return screen
        }
    }
    var best: NSScreen?
    var bestDist: CGFloat = .infinity
    for screen in NSScreen.screens {
        let sf = screen.frame
        let dx = max(0, max(sf.minX - center.x, center.x - sf.maxX))
        let dy = max(0, max(sf.minY - center.y, center.y - sf.maxY))
        let dist = dx * dx + dy * dy
        if dist < bestDist {
            bestDist = dist
            best = screen
        }
    }
    return best
}

func appKitRectFromTopLeft(_ tlRect: NSRect, screen: NSScreen) -> NSRect {
    let sf = screen.frame
    let y = sf.maxY - tlRect.maxY
    return NSRect(x: tlRect.origin.x, y: y, width: tlRect.width, height: tlRect.height)
}
