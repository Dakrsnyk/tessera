import XCTest

extension XCUIElement {
    /// A tool of the Studio's bar scrolled off the screen (« Contenu » is the last one since 2026-11-26): drags the
    /// bar itself, on the tool's row, toward it. isHittable fails (« Activation point invalid ») on such a button, and
    /// a swipe on « a scroll view containing it » could land on the stage.
    func scrollToolOnScreen(in app: XCUIApplication) {
        let width = app.windows.firstMatch.frame.width
        for _ in 0..<4 {
            let frame = self.frame
            guard frame.minX < 0 || frame.maxX > width else { return }
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let left = origin.withOffset(CGVector(dx: width * 0.2, dy: frame.midY))
            let right = origin.withOffset(CGVector(dx: width * 0.8, dy: frame.midY))
            if frame.minX < 0 { left.press(forDuration: 0.05, thenDragTo: right) } else { right.press(forDuration: 0.05, thenDragTo: left) }
        }
    }
}
