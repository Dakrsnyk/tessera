import SwiftUI
import WidgetKit

/// Creating widgets from a space: pick one or several of its widgets, give them a style and a color,
/// save. They join « Mes widgets » (with a short flight to the tab). The space's data stays one tap away.
/// Creating widgets from a space: pick a size, one or several of its widgets, a style and a color, save.
/// Small shows one piece of information; medium shows a widget's medium layout or two widgets side by side;
/// large shows a widget's large layout or up to four widgets, like a dashboard of the space.
/// They join « Mes widgets » (with a short flight to the tab). The space's data stays one tap away.
struct SpaceBuilderView: View {
    let space: Space
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var format: WidgetFormat = .small
    /// Selected widgets, in the order they were picked.
    @State private var selection: [WidgetKind]
    @State private var themeID: ThemeID
    @State private var accentHex: String
    /// The name and content settings of each widget, whatever the size: kept per widget so they
    /// survive a change of size or selection.
    @State private var configured: [WidgetKind: WidgetDesign] = [:]
    /// The name of a combined widget, when the user changed it.
    @State private var comboName: String?
    @State private var showsPaywall = false
    @State private var previewFrame: CGRect = .zero
    /// Test builds: the size or selection asked for by a capture is applied once, not again on coming
    /// back from « Mes données ».
    @State private var appliedCaptureOptions = false

    init(space: Space) {
        self.space = space
        let first = SpaceCatalog.preset(for: space, format: .small).first ?? .note
        let base = Self.design(for: first)
        _selection = State(initialValue: [first])
        _themeID = State(initialValue: base.themeID)
        _accentHex = State(initialValue: base.accentHex)
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

    /// A widget's own settings (name, content), as the user left them.
    private func base(_ kind: WidgetKind) -> WidgetDesign {
        configured[kind] ?? Self.design(for: kind)
    }

    private func binding(_ kind: WidgetKind) -> Binding<WidgetDesign> {
        Binding(get: { base(kind) }, set: { configured[kind] = $0 })
    }

    /// A widget of this space in the chosen style.
    private func styled(_ kind: WidgetKind) -> WidgetDesign {
        var design = base(kind)
        design.themeID = themeID
        design.accentHex = accentHex
        return design
    }

    private var plan: Composer.Plan {
        format == .small ? .invalid("") : Composer.plan(selection, format: format)
    }

    /// The medium or large widget built from the selection, or nil while the selection doesn't fit.
    private var composed: WidgetDesign? {
        switch plan {
        case let .single(kind):
            var design = styled(kind)
            design.format = format
            return design
        case let .combo(slots):
            var options = DesignOptions()
            options.parts = slots.map { slot in
                let part = base(slot.kind)
                return ComboPart(kind: slot.kind, options: part.options, name: part.name, size: slot.size)
            }
            return WidgetDesign(
                name: comboName?.trimmed.nonEmpty ?? slots.map { base($0.kind).name }.joined(separator: " + "),
                kind: slots[0].kind, themeID: themeID, accentHex: accentHex,
                options: options, format: format
            )
        case .invalid:
            return nil
        }
    }

    /// What « Enregistrer » saves: one small widget per selected kind, or the one medium or large widget.
    private var designs: [WidgetDesign] {
        if format == .small {
            return selection.map { kind in
                var design = styled(kind)
                design.format = .small
                return design
            }
        }
        return composed.map { [$0] } ?? []
    }

    private var needsPremium: Bool { !model.isPremium && designs.contains(where: \.usesPremiumFeatures) }
    private var exceedsFreeLimit: Bool { !model.isPremium && model.designs.count + designs.count > AppModel.freeDesignLimit }
    /// The widget shown on its own, whose name and content are edited in place.
    private var singleKind: WidgetKind? {
        if format == .small { return selection.count == 1 ? selection.first : nil }
        if case let .single(kind) = plan { return kind }
        return nil
    }

    private func payload(_ design: WidgetDesign) -> WidgetPayload {
        usesOwnData ? model.payload(for: design) : SamplePayload.make(for: design)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    formatPicker
                    preview
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
                    if needsPremium { premiumNotice }
                    widgetsSection
                    if let kind = singleKind {
                        nameSection(binding(kind))
                    } else if !selection.isEmpty {
                        contentSection
                    }
                    styleSection
                    colorSection
                    if let kind = singleKind { KindOptionsSection(design: binding(kind)) }
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
                    // The data opens on top of the creator: back returns to the widget as it was,
                    // now showing what was just entered.
                    NavigationLink {
                        SpaceView(space: space, isEmbedded: true)
                    } label: {
                        Label("Mes données", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("space-data")
                    .accessibilityLabel(Text("Mes données de l'espace \(space.title)"))
                }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .task(id: selection) {
                for design in designs { await model.prepare(design) }
            }
            #if DEBUG
            .onAppear {
                // Test captures: several widgets selected, or a size chosen.
                guard !appliedCaptureOptions else { return }
                appliedCaptureOptions = true
                let defaults = UserDefaults.standard
                if let raw = defaults.string(forKey: "screenshotCreatorFormat"), let size = WidgetFormat(rawValue: raw) {
                    setFormat(size)
                } else if defaults.bool(forKey: "screenshotCreatorMulti") {
                    selection = Array(kinds.prefix(3))
                }
            }
            #endif
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
                Text("Choisis une taille, tes widgets, puis leur style.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Taille", selection: Binding(get: { format }, set: { setFormat($0) })) {
                ForEach(WidgetFormat.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(formatHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formatHint: String {
        switch format {
        case .small: "L'essentiel en un coup d'œil. Choisis-en plusieurs pour créer plusieurs petits widgets."
        case .medium: "Plus d'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte."
        case .large: "Un tableau de bord de l'espace : un widget en grand, ou jusqu'à 4 widgets réunis."
        }
    }

    /// The widget as it will look on the Home Screen, at its real proportions.
    @ViewBuilder private var preview: some View {
        ZStack {
            LinearGradient(
                colors: [Color(light: "DCE3EA", dark: "1B1F26"), Color(light: "C9D3DD", dark: "11141A")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            previewContent
                .padding(20)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: format)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, 4)
    }

    @ViewBuilder private var previewContent: some View {
        if format == .small {
            if selection.count == 1, let design = designs.first {
                WidgetPreview(design: design, family: .systemSmall, payload: payload(design), width: 170)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selection) { kind in
                            let design = styled(kind)
                            WidgetPreview(design: design, family: .systemSmall, payload: payload(design), width: 128)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
            }
        } else if let design = composed {
            VStack(spacing: 10) {
                WidgetPreview(design: design, family: format.family, payload: payload(design))
                    .frame(maxWidth: 364)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                if design.isCombo {
                    Text("Réunit : \(design.options.parts.map(\.name).joined(separator: " · "))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            // Empty frame at the real size, with what to pick.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .aspectRatio(format.family.aspectRatio, contentMode: .fit)
                .frame(maxWidth: 364)
                .overlay {
                    if case let .invalid(message) = plan {
                        Text(message)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(18)
                    }
                }
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
        EditorSection(title: "Widgets", detail: widgetsDetail) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 14) {
                ForEach(kinds) { kind in
                    kindCell(kind)
                }
            }
        }
    }

    /// Whether a widget can take part in a widget of this size (on its own, or combined).
    private static func fits(_ kind: WidgetKind, _ format: WidgetFormat) -> Bool {
        switch format {
        case .small: kind.families.contains(.systemSmall)
        case .medium: kind.families.contains(.systemSmall) || kind.families.contains(.systemMedium)
        case .large: kind.homeFamilies.isEmpty == false
        }
    }

    private var widgetsDetail: String {
        let count = Fmt.plural(selection.count, "sélectionné", "sélectionnés")
        return format == .small ? count : "\(count) · \(Composer.maxCount(for: format)) au plus"
    }

    private func kindCell(_ kind: WidgetKind) -> some View {
        let isSelected = selection.contains(kind)
        let order = (selection.firstIndex(of: kind) ?? 0) + 1
        let isAvailable = Self.fits(kind, format)
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
                    // Order matters for medium and large widgets: it is the order they are laid out in.
                    Image(systemName: isSelected ? (format == .small ? "checkmark.circle.fill" : "\(order).circle.fill") : "circle")
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
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.35)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .accessibilityLabel(Text(kind.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Several widgets (small ones, or combined into a medium or large one): each keeps its own name and
    /// content, set on its own page; a combined widget also gets its name.
    private var contentSection: some View {
        EditorSection(title: "Contenu", detail: "Règle chaque widget") {
            VStack(spacing: 0) {
                if composed != nil {
                    TextField("Nom du widget", text: Binding(
                        get: { comboName ?? composed?.name ?? "" },
                        set: { comboName = $0 }
                    ))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .padding(12)
                    .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("combo-name")
                }
                ForEach(Array(selection.enumerated()), id: \.element) { pair in
                    if pair.offset > 0 { Divider() }
                    NavigationLink {
                        PartSettingsView(design: binding(pair.element), style: (themeID, accentHex), usesOwnData: usesOwnData)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: pair.element.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(base(pair.element).name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                Text(pair.element.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Régler")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("part-\(pair.element.rawValue)")
                }
            }
        }
    }

    private func nameSection(_ design: Binding<WidgetDesign>) -> some View {
        EditorSection(title: "Nom") {
            TextField("Nom du widget", text: design.name)
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
            .disabled(designs.isEmpty)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var saveTitle: String {
        if needsPremium { return "Débloquer et enregistrer" }
        if format != .small { return "Enregistrer le widget \(format.title.lowercased())" }
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
                // Full: the oldest choice makes room for the new one.
                if selection.count >= Composer.maxCount(for: format) { selection.removeFirst() }
                selection.append(kind)
            }
        }
    }

    private func setFormat(_ newFormat: WidgetFormat) {
        guard newFormat != format else { return }
        Haptics.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            format = newFormat
            let preset = SpaceCatalog.preset(for: space, format: newFormat)
            if !preset.isEmpty { selection = preset }
            comboName = nil
        }
    }

    private func save() {
        if needsPremium || exceedsFreeLimit {
            showsPaywall = true
            return
        }
        let saved = designs
        guard !saved.isEmpty else { return }
        model.install(designs: saved)
        Haptics.success()
        router.saveFlight = SaveFlight(designs: saved, source: previewFrame)
        dismiss()
    }
}

/// One widget of a creation made of several: its name and content settings, with its preview.
private struct PartSettingsView: View {
    @Binding var design: WidgetDesign
    let style: (ThemeID, String)
    let usesOwnData: Bool
    @Environment(AppModel.self) private var model

    private var styled: WidgetDesign {
        var styled = design
        styled.themeID = style.0
        styled.accentHex = style.1
        return styled
    }

    var body: some View {
        let family: WidgetFamily = design.kind.families.contains(.systemSmall) ? .systemSmall : .systemMedium
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                WidgetPreview(
                    design: styled, family: family,
                    payload: usesOwnData ? model.payload(for: styled) : SamplePayload.make(for: styled),
                    width: family == .systemSmall ? 170 : 330
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                EditorSection(title: "Nom") {
                    TextField("Nom du widget", text: $design.name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                KindOptionsSection(design: $design)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.screenFill)
        .navigationTitle(design.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
