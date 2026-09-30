import SwiftUI

/// « Mes informations » on Home: how complete the profile is, and each followed area at a glance.
struct MyInfoCard: View {
    @Environment(AppModel.self) private var model
    @State private var editsInterests = false

    var body: some View {
        let completion = model.completion
        let areas = model.followedAreas
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mes informations")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink(value: HomeRoute.info) {
                    Text("Tout voir")
                        .font(.subheadline.weight(.medium))
                }
                .accessibilityLabel(Text("Tout voir : Mes informations"))
            }
            if model.profile.interests.isEmpty {
                prompt
            }
            if !areas.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    NavigationLink(value: HomeRoute.info) {
                        HStack(spacing: 14) {
                            CompletionRing(filled: completion.filled, total: completion.total)
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(headline(completion))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(detail(completion.missing))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("home-info")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(areas) { area in
                                NavigationLink(value: HomeRoute.infoArea(area)) {
                                    AreaBadge(area: area, missing: model.missingItems(area.keyItems).count)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("info-\(area.rawValue)")
                            }
                        }
                    }
                }
                .card()
            }
        }
        .sheet(isPresented: $editsInterests) { InterestsEditorSheet() }
    }

    private func headline(_ completion: (filled: Int, total: Int, missing: [DataItem])) -> String {
        if completion.missing.isEmpty { return "Ton profil est complet" }
        return completion.filled * 3 >= completion.total * 2 ? "Ton profil est presque complet" : "Complète ton profil"
    }

    private func detail(_ missing: [DataItem]) -> String {
        guard !missing.isEmpty else { return "Tes widgets et « Mon Quotidien » utilisent tes vraies données." }
        let names = missing.prefix(2).map { $0.title.lowercasedFirst }
        return "Il manque : \(names.joined(separator: ", "))\(missing.count > 2 ? "…" : ".")"
    }

    /// No interest and no data yet: an invitation, never empty cards.
    private var prompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Personnalise Tessera", systemImage: "sparkles")
                .font(.headline)
            Text("Dis ce qui t'intéresse : tes widgets et « Mon Quotidien » reprendront tes objectifs, ton programme, ton budget… sans que tu aies à les répéter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                editsInterests = true
            } label: {
                Text("Choisir mes centres d'intérêt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .card()
    }
}

/// How much of the profile is given, as a ring with « 7/9 ».
struct CompletionRing: View {
    let filled: Int
    let total: Int

    var body: some View {
        ZStack {
            RingView(progress: total == 0 ? 1 : Double(filled) / Double(total), lineWidth: 6, color: .accentColor, track: Color.accentColor.opacity(0.15))
            Text("\(filled)/\(total)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(filled) sur \(total) renseignées"))
    }
}

private struct AreaBadge: View {
    let area: InfoArea
    let missing: Int

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: area.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color(hex: area.colorHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(area.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(missing == 0 ? "✓" : "À compléter")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(missing == 0 ? Color.accentColor : Color(light: "8A4B00", dark: "F5B25A"))
        }
        .frame(width: 76)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The center

/// Every piece of data Tessera can use, grouped by area: given once here (or while making a widget),
/// used everywhere. The person's areas first, the others below.
struct MyInfoView: View {
    @Environment(AppModel.self) private var model
    @State private var editsInterests = false

    var body: some View {
        let followed = model.followedAreas
        let others = InfoArea.allCases.filter { !followed.contains($0) && $0 != .general }
        let completion = model.completion
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Tout ce que tes widgets savent de toi. Renseigné une fois ici ou en créant un widget, c'est utilisé partout : widgets, « Mon Quotidien » et statistiques.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    CompletionRing(filled: completion.filled, total: completion.total)
                        .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(completion.missing.isEmpty ? "Tout est renseigné" : Fmt.plural(completion.missing.count, "information à compléter", "informations à compléter"))
                            .font(.headline)
                        Button("Mes centres d'intérêt") { editsInterests = true }
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer(minLength: 0)
                }
                .card()
                if !followed.isEmpty {
                    areaList("Tes thèmes", followed)
                }
                areaList(followed.isEmpty ? "Catégories" : "Autres catégories", others)
                areaList("Général", [.general])
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(.screenFill)
        .screenshotScroll()
        .navigationTitle("Mes informations")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $editsInterests) { InterestsEditorSheet() }
    }

    private func areaList(_ title: String, _ areas: [InfoArea]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(areas.enumerated()), id: \.element) { pair in
                    NavigationLink(value: HomeRoute.infoArea(pair.element)) {
                        AreaRow(area: pair.element)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("area-\(pair.element.rawValue)")
                    if pair.offset < areas.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct AreaRow: View {
    let area: InfoArea
    @Environment(AppModel.self) private var model

    var body: some View {
        let summaries = area.items.compactMap { item in model.summary(item) }
        let missing = model.missingItems(area.keyItems).count
        HStack(spacing: 12) {
            Image(systemName: area.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color(hex: area.colorHex), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(area.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(summaries.isEmpty ? "Rien de renseigné" : summaries.prefix(3).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            if missing > 0 && !summaries.isEmpty {
                Text("\(missing)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(light: "8A4B00", dark: "F5B25A"))
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Color(light: "FCE8CC", dark: "4A3314"), in: Circle())
                    .accessibilityLabel(Text("\(missing) à compléter"))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One area of « Mes informations »: every piece of data it holds, the widgets that use them,
/// and the finer questions of the first launch.
struct InfoAreaView: View {
    let area: InfoArea
    @Environment(AppModel.self) private var model
    @State private var editsTopic = false

    var body: some View {
        let users = model.designs.filter { design in !Set(design.dataItems).isDisjoint(with: area.items) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: area.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: area.colorHex), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Text(users.isEmpty ? "Ce que tu renseignes ici servira à tes widgets \(area.title.lowercasedFirst) et à « Mon Quotidien »." : "Utilisé par \(Fmt.plural(users.count, "de tes widgets", "de tes widgets")) : \(users.prefix(3).map(\.name).joined(separator: ", ")).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                WidgetDataSection(items: area.items, title: "Tes données")
                if let topic = area.topic {
                    Button {
                        editsTopic = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Plus de précisions")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(topic.purpose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .card(padding: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("area-more")
                }
                if let space = area.space {
                    NavigationLink {
                        SpaceView(space: space, isEmbedded: true)
                    } label: {
                        Label("Toutes les données \(space.title)", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.screenFill)
        .navigationTitle(area.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $editsTopic) {
            if let topic = area.topic { TopicEditorSheet(topic: topic) }
        }
    }
}

extension String {
    /// « Objectif calorique » → « objectif calorique », to fit in a sentence.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
