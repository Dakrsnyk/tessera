import SwiftUI
import WidgetKit

/// Creating widgets from a space: pick one or several of its widgets, give them a style and a color,
/// save. They join « Mes widgets » (with a short flight to the tab). The space's data stays one tap away.
struct SpaceBuilderView: View {
    let space: Space
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    /// Selected widgets, in the order they were picked.
    @State private var selection: [WidgetKind]
    @State private var themeID: ThemeID
    @State private var accentHex: String
    /// The widget being edited when only one is selected (name and options).
    @State private var single: WidgetDesign
    @State private var family: WidgetFamily
    @State private var showsPaywall = false
    @State private var previewFrame: CGRect = .zero

    init(space: Space) {
        self.space = space
        let kinds = SpaceCatalog.kinds(in: space)
        let first = kinds.first(where: { !$0.isPremium }) ?? kinds.first ?? .note
        let base = Self.design(for: first)
        _selection = State(initialValue: [first])
        _themeID = State(initialValue: base.themeID)
        _accentHex = State(initialValue: base.accentHex)
        _single = State(initialValue: base)
        _family = State(initialValue: first.homeFamilies.first ?? .systemSmall)
    }

    private var kinds: [WidgetKind] { SpaceCatalog.kinds(in: space) }
    private var usesOwnData: Bool { model.hasData(in: space) }

    private static func design(for kind: WidgetKind) -> WidgetDesign {
        var design = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
        design.name = kind.title
        design.background = .theme
        design.font = .theme
        return design
    }

    /// A widget of this space in the chosen style.
    private func styled(_ kind: WidgetKind) -> WidgetDesign {
        var design = selection == [kind] && single.kind == kind ? single : Self.design(for: kind)
        design.themeID = themeID
        design.accentHex = accentHex
        return design
    }

    /// What « Enregistrer » saves: one widget per selected kind.
    private var designs: [WidgetDesign] { selection.map(styled) }

    private var needsPremium: Bool { !model.isPremium && designs.contains(where: \.usesPremiumFeatures) }
    private var exceedsFreeLimit: Bool { !model.isPremium && model.designs.count + selection.count > AppModel.freeDesignLimit }

    private func payload(_ design: WidgetDesign) -> WidgetPayload {
        usesOwnData ? model.payload(for: design) : SamplePayload.make(for: design)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    preview
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
                    if needsPremium { premiumNotice }
                    widgetsSection
                    if selection.count == 1 { nameSection }
                    styleSection
                    colorSection
                    if selection.count == 1 { KindOptionsSection(design: $single) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.screenFill)
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(space.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            router.openSpace(space)
                        }
                    } label: {
                        Label("Mes données", systemImage: "square.and.pencil")
                    }
                    .accessibilityLabel(Text("Mes données de l'espace \(space.title)"))
                }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .task(id: selection) {
                for design in designs { await model.prepare(design) }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: space.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color(hex: space.colorHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Crée ton widget")
                    .font(.title3.weight(.semibold))
                Text("Choisis un ou plusieurs widgets, puis leur style.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var preview: some View {
        if selection.count == 1, let design = designs.first {
            PreviewStage(design: design, family: $family, payload: payload(design))
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(light: "DCE3EA", dark: "1B1F26"), Color(light: "C9D3DD", dark: "11141A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selection) { kind in
                            let design = styled(kind)
                            let family: WidgetFamily = kind.families.contains(.systemSmall) ? .systemSmall : .systemMedium
                            WidgetPreview(design: design, family: family, payload: payload(design), width: 128 * family.aspectRatio)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.top, 8)
        }
    }

    private var premiumNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.premiumInk)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.count > 1 ? "Ces widgets utilisent Premium" : "Ce widget utilise Premium")
                    .font(.subheadline.weight(.semibold))
                Text(Array(Set(designs.flatMap(\.premiumFeatures))).sorted().joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { showsPaywall = true } label: {
                Text("Débloquer").foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color.premiumFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var widgetsSection: some View {
        EditorSection(title: "Widgets", detail: Fmt.plural(selection.count, "sélectionné", "sélectionnés")) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 14) {
                ForEach(kinds) { kind in
                    kindCell(kind)
                }
            }
        }
    }

    private func kindCell(_ kind: WidgetKind) -> some View {
        let isSelected = selection.contains(kind)
        let design = styled(kind)
        let family: WidgetFamily = kind.families.contains(.systemSmall) ? .systemSmall : .systemMedium
        return Button {
            toggle(kind)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    WidgetPreview(design: design, family: family, payload: payload(design))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                        }
                        .scaleEffect(isSelected ? 0.96 : 1)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.white), isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear))
                        .shadow(color: .black.opacity(isSelected ? 0 : 0.35), radius: 2)
                        .padding(5)
                }
                HStack(spacing: 4) {
                    Text(kind.title)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if kind.isPremium && !model.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.premiumInk)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .accessibilityLabel(Text(kind.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var nameSection: some View {
        EditorSection(title: "Nom") {
            TextField("Nom du widget", text: $single.name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(12)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var styleSection: some View {
        EditorSection(title: "Style", detail: ThemeCatalog.theme(themeID).tagline) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ThemeCatalog.all) { theme in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { themeID = theme.id }
                                Haptics.tap()
                            } label: {
                                ThemeSwatch(theme: theme, accentHex: accentHex, isSelected: themeID == theme.id, showsLock: theme.isPremium && !model.isPremium)
                            }
                            .buttonStyle(.plain)
                            .id(theme.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear { proxy.scrollTo(themeID, anchor: .center) }
            }
        }
    }

    private var colorSection: some View {
        EditorSection(title: "Couleur", detail: Palette.name(for: accentHex)) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                ForEach(Palette.freeAccents) { swatch in
                    ColorDot(hex: swatch.hex, isSelected: accentHex == swatch.hex) {
                        accentHex = swatch.hex
                        Haptics.tap()
                    }
                    .accessibilityLabel(Text(swatch.name))
                }
                ColorPicker("Couleur personnalisée", selection: Binding(
                    get: { Color(hex: accentHex) },
                    set: { accentHex = $0.hexString }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: save) {
                Text(saveTitle)
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var saveTitle: String {
        if needsPremium { return "Débloquer et enregistrer" }
        return selection.count == 1 ? "Enregistrer le widget" : "Enregistrer les \(selection.count) widgets"
    }

    // MARK: Actions

    private func toggle(_ kind: WidgetKind) {
        Haptics.tap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            if let index = selection.firstIndex(of: kind) {
                guard selection.count > 1 else { return }
                selection.remove(at: index)
            } else {
                selection.append(kind)
            }
            // Back to one widget: edit that one (name, options, size).
            if selection.count == 1, let only = selection.first, single.kind != only {
                single = Self.design(for: only)
                family = only.homeFamilies.first ?? .systemSmall
            }
        }
    }

    private func save() {
        if needsPremium || exceedsFreeLimit {
            showsPaywall = true
            return
        }
        let saved = designs
        model.install(designs: saved)
        Haptics.success()
        router.saveFlight = SaveFlight(designs: saved, source: previewFrame)
        dismiss()
    }
}
