import Foundation

/// A text shown to people. The code is written in French; `tr(_:)` looks the French text up in
/// `Localizable.xcstrings` and returns it in the language of the iPhone (French when it is French,
/// English when the language isn't offered).
///
/// The key is the French text itself. Each interpolated value becomes `%@` in the key and is put
/// back in its place after translation, so a translation can move it:
/// `tr("\(count) séances")` looks up `"%@ séances"`, which English gives as `"%@ sessions"`.
/// In a key with values, a literal `%` is written `%%`.
struct LocalizedText: ExpressibleByStringInterpolation {
    let key: String
    let arguments: [String]

    init(stringLiteral value: String) {
        key = value
        arguments = []
    }

    init(stringInterpolation: Interpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }

    struct Interpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity + interpolationCount * 2)
        }

        mutating func appendLiteral(_ literal: String) {
            key += literal.replacingOccurrences(of: "%", with: "%%")
        }

        mutating func appendInterpolation<T>(_ value: T) {
            key += "%@"
            arguments.append(String(describing: value))
        }

        mutating func appendInterpolation(_ value: String) {
            key += "%@"
            arguments.append(value)
        }

        mutating func appendInterpolation(_ value: Double, specifier: String) {
            key += "%@"
            arguments.append(String(format: specifier, locale: Fmt.locale, value))
        }

        mutating func appendInterpolation<F: FormatStyle>(_ value: F.FormatInput, format: F) where F.FormatOutput == String {
            key += "%@"
            arguments.append(format.format(value))
        }
    }
}

/// The text in the language of the iPhone.
func tr(_ text: LocalizedText) -> String {
    let translated = Localization.bundle.localizedString(forKey: text.key, value: text.key, table: nil)
    guard !text.arguments.isEmpty else { return translated }
    return String(format: translated, locale: Fmt.locale, arguments: text.arguments.map { NSString(string: $0) })
}

enum Localization {
    static let bundle = Bundle.main

    /// The language the interface is shown in ("fr", "en", "pt-BR", "zh-Hans"…).
    static let language: String = bundle.preferredLocalizations.first ?? "en"

    /// True when the interface is in French (some French-only typography follows from it).
    static var isFrench: Bool { language.hasPrefix("fr") }

    /// The languages Tessera is translated into, French first.
    static let supported = ["fr", "en", "es", "de", "it", "pt-BR", "ja", "zh-Hans", "ko"]
}
