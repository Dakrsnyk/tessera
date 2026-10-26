import Foundation

/// A saved list read element by element: one that can no longer be read (the kind of a widget that was
/// removed from Ardane, like the weather ones) is left out, and all the others are kept.
struct LossyList<Element: Decodable>: Decodable {
    var elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                // A failed element is not consumed: skip it with a value that accepts anything.
                _ = try? container.decode(Skipped.self)
            }
        }
        self.elements = elements
    }

    private struct Skipped: Decodable {
        init(from decoder: Decoder) throws {}
    }
}
