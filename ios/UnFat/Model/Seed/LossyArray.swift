import Foundation

/// Decodes a JSON array element by element and drops elements that fail to decode, so one bad
/// seed item does not empty the whole catalog.
struct LossyArray<Element: Decodable>: Decodable {
    var elements: [Element]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                // A failed decode does not advance the container; consume the element explicitly.
                _ = try? container.decode(Skipped.self)
            }
        }
        self.elements = elements
    }

    private struct Skipped: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}
