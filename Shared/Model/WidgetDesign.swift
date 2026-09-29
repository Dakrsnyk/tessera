import Foundation

enum BackgroundStyle: Codable, Hashable {
    /// The theme's own background.
    case theme
    /// A flat color picked by the user.
    case color(String)
    /// A soft gradient built from the accent color.
    case gradient
    /// A photo stored in the shared container, identified by file name.
    case photo(String)

    var isPremium: Bool { self != .theme }

    var title: String {
        switch self {
        case .theme: "Thème"
        case .color: "Couleur"
        case .gradient: "Dégradé"
        case .photo: "Photo"
        }
    }
}

enum FontChoice: String, Codable, CaseIterable, Identifiable {
    case theme, standard, rounded, serif, mono
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Thème"
        case .standard: "Standard"
        case .rounded: "Arrondie"
        case .serif: "Serif"
        case .mono: "Mono"
        }
    }

    var isPremium: Bool { self == .serif || self == .mono }
}

enum ContentAlignment: String, Codable, CaseIterable, Identifiable {
    case leading, center
    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: "À gauche"
        case .center: "Centré"
        }
    }
}

/// A widget the user has designed in the app. Widgets on the Home Screen point to one of these.
struct WidgetDesign: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var kind: WidgetKind
    var themeID: ThemeID
    var accentHex: String
    var background: BackgroundStyle
    var font: FontChoice
    var showsTitle: Bool
    var showsDetails: Bool
    var alignment: ContentAlignment
    var options: DesignOptions
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    /// The size the widget was created for (small, medium or large). Nil for widgets made before sizes
    /// were chosen: they show at their smallest size.
    var format: WidgetFormat?

    init(
        id: UUID = UUID(),
        name: String? = nil,
        kind: WidgetKind,
        themeID: ThemeID = .minimal,
        accentHex: String = Palette.defaultAccent,
        background: BackgroundStyle = .theme,
        font: FontChoice = .theme,
        showsTitle: Bool = true,
        showsDetails: Bool = true,
        alignment: ContentAlignment = .leading,
        options: DesignOptions = DesignOptions(),
        isFavorite: Bool = false,
        format: WidgetFormat? = nil
    ) {
        self.id = id
        self.name = name ?? kind.title
        self.kind = kind
        self.themeID = themeID
        self.accentHex = accentHex
        self.background = background
        self.font = font
        self.showsTitle = showsTitle
        self.showsDetails = showsDetails
        self.alignment = alignment
        self.options = options
        self.isFavorite = isFavorite
        self.format = format
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsedAt = nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, themeID, accentHex, background, font, showsTitle, showsDetails
        case alignment, options, isFavorite, createdAt, updatedAt, lastUsedAt, format
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(WidgetKind.self, forKey: .kind)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? kind.title
        themeID = (try? c.decodeIfPresent(ThemeID.self, forKey: .themeID)) ?? .minimal
        accentHex = (try? c.decodeIfPresent(String.self, forKey: .accentHex)) ?? Palette.defaultAccent
        background = (try? c.decodeIfPresent(BackgroundStyle.self, forKey: .background)) ?? .theme
        font = (try? c.decodeIfPresent(FontChoice.self, forKey: .font)) ?? .theme
        showsTitle = (try? c.decodeIfPresent(Bool.self, forKey: .showsTitle)) ?? true
        showsDetails = (try? c.decodeIfPresent(Bool.self, forKey: .showsDetails)) ?? true
        alignment = (try? c.decodeIfPresent(ContentAlignment.self, forKey: .alignment)) ?? .leading
        options = (try? c.decodeIfPresent(DesignOptions.self, forKey: .options)) ?? DesignOptions()
        isFavorite = (try? c.decodeIfPresent(Bool.self, forKey: .isFavorite)) ?? false
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
        lastUsedAt = try? c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        format = try? c.decodeIfPresent(WidgetFormat.self, forKey: .format)
    }

    var theme: WidgetTheme { ThemeCatalog.theme(themeID) }

    /// The Premium features this design relies on, used to explain what a save would unlock.
    var premiumFeatures: [String] {
        var features: [String] = []
        // A combined widget needs Premium as soon as one of the widgets inside does.
        for part in partDesigns where part.kind.isPremium {
            features.append("Widget \(part.kind.title)")
        }
        if theme.isPremium { features.append("Style \(theme.name)") }
        if background.isPremium { features.append("Fond \(background.title.lowercased())") }
        if font.isPremium { features.append("Police \(font.title)") }
        if !Palette.freeAccents.contains(where: { $0.hex == accentHex }) { features.append("Couleur personnalisée") }
        return features
    }

    var usesPremiumFeatures: Bool { !premiumFeatures.isEmpty }

    /// What a free user sees when a design uses Premium styling: same content, free look.
    func downgradedForFree() -> WidgetDesign {
        var copy = self
        if theme.isPremium { copy.themeID = .minimal }
        if background.isPremium { copy.background = .theme }
        if font.isPremium { copy.font = .theme }
        if !Palette.freeAccents.contains(where: { $0.hex == accentHex }) { copy.accentHex = Palette.defaultAccent }
        return copy
    }

    static func starter(for kind: WidgetKind) -> WidgetDesign {
        WidgetDesign(kind: kind)
    }
}
