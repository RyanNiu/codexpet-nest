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

func primaryScreen() -> NSScreen? {
    NSScreen.screens.first {
        abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5
    }
}

func topLeftFrame(for screen: NSScreen) -> NSRect {
    let primary = primaryScreen() ?? NSScreen.screens.first!
    let primaryMaxY = primary.frame.maxY
    return NSRect(
        x: screen.frame.minX,
        y: primaryMaxY - screen.frame.maxY,
        width: screen.frame.width,
        height: screen.frame.height
    )
}

func screenForTopLeftRect(_ rect: NSRect) -> NSScreen? {
    let center = NSPoint(x: rect.midX, y: rect.midY)

    if let screen = NSScreen.screens.first(where: {
        topLeftFrame(for: $0).contains(center)
    }) {
        return screen
    }

    return NSScreen.screens.min { s1, s2 in
        distanceSquared(center, to: topLeftFrame(for: s1))
            < distanceSquared(center, to: topLeftFrame(for: s2))
    }
}

func appKitRectFromTopLeft(_ rect: NSRect, screen: NSScreen) -> NSRect {
    let screenTopLeftFrame = topLeftFrame(for: screen)
    let localX = rect.minX - screenTopLeftFrame.minX
    let localY = rect.minY - screenTopLeftFrame.minY

    return NSRect(
        x: screen.frame.minX + localX,
        y: screen.frame.maxY - localY - rect.height,
        width: rect.width,
        height: rect.height
    )
}

func distanceSquared(_ point: NSPoint, to rect: NSRect) -> CGFloat {
    let clampedX = min(max(point.x, rect.minX), rect.maxX)
    let clampedY = min(max(point.y, rect.minY), rect.maxY)
    let dx = point.x - clampedX
    let dy = point.y - clampedY
    return dx * dx + dy * dy
}
