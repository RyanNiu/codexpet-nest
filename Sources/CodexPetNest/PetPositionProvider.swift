import AppKit

protocol PetPositionProvider {
    func read() -> PetReadResult
}

final class CodexPetPositionProvider: PetPositionProvider {
    private let reader: PetPositionReader

    init(reader: PetPositionReader) {
        self.reader = reader
    }

    func read() -> PetReadResult {
        reader.read()
    }
}

final class StandalonePetPositionProvider: PetPositionProvider {
    private weak var window: StandalonePetWindow?

    init(window: StandalonePetWindow) {
        self.window = window
    }

    func read() -> PetReadResult {
        guard let window, window.isVisible else {
            return .unavailable
        }
        let frame = window.frame
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return .unavailable
        }
        let screenTopLeftFrame = topLeftFrame(for: screen)
        let topLeftX = screenTopLeftFrame.minX + (frame.minX - screen.frame.minX)
        let topLeftY = screenTopLeftFrame.minY + (screen.frame.maxY - frame.maxY)
        let bounds = PetBounds(
            x: topLeftX,
            y: topLeftY,
            width: frame.width,
            height: frame.height
        )
        return .open(bounds: bounds)
    }
}
