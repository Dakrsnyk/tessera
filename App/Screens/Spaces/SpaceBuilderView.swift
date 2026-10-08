import SwiftUI
import WidgetKit

/// Creating widgets from a space, first step: pick a size and one or several of its widgets.
/// Small shows one piece of information; medium shows a widget's medium layout or two widgets side by side;
/// large shows a widget's large layout or up to four widgets, like a dashboard of the space.
/// « Personnaliser » then opens them in the Widget Studio, where they are styled and saved.
/// The space's data stays one tap away.
struct SpaceBuilderView: View {
    let space: Space
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var format: WidgetFormat = .small
    /// Selected widgets, in the order they were picked.
    @State private var selection: [WidgetKind]
    /// The Studio, pushed over the selection.
    @State private var customizes = false
    /// Test builds: the size or selection asked for by a capture is applied once, not again on coming
    /// back from « Mes données ».
    @State private var appliedCaptureOptions = false
    /// Only the widgets usable without opening the app.
    @State private var onlyInteractive = false
    /// The look every widget of the creation starts with (the space's first widget's), so they match.
    private let themeID: ThemeID
    private let accentHex: String

    init(space: Space) {
        self.space = space
        let first = SpaceCatalog.preset(for: space, format: .small).first ?? .note
        let base = Self.design(for: first)
        _selection = State(initialValue: [first])
        themeID = base.themeID
        accentHex = base.accentHex
    }

    private var kinds: [WidgetKind] { SpaceCatalog.kinds(in: space) }

    private static func design(for kind: WidgetKind) -> WidgetDesign {
        var design = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
        design.name = kind.title
        design.background = .theme
        design.font = .theme
        return design
    }

    /// A widget of this space in the creation's look.
    private func styled(_ kind: WidgetKind) -> WidgetDesign {
        var design = Self.design(for: kind)
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
                let part = Self.design(for: slot.kind)
                return ComboPart(kind: slot.kind, options: part.options, name: part.name, size: slot.size)
            }
            return WidgetDesign(
                name: slots.map { Self.design(for: $0.kind).name }.joined(separator: " + "),
                kind: slots[0].kind, themeID: themeID, accentHex: accentHex,
                options: options, format: format
            )
        case .invalid:
            return nil
        }
    }

    /// What the Studio opens with: one small widget per selected kind, or the one medium or large widget.
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

    /// Each widget shows the person's data once they gave what it needs, marked example data before.
    private func payload(_ design: WidgetDesign) -> WidgetPayload {
        model.previewPayload(for: design)
    }

    private var showsExample: Bool { designs.contains { !model.hasOwnData(for: $0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    formatPicker
                    preview
                    widgetsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.screenGradient)
            .safeAreaInset(edge: .bottom) { continueBar }
            .navigationTitle(space.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // The data opens on top of the creator: back returns to the widget as it was,
                    // now showing what was just entered.
                    NavigationLink {
                        SpaceView(space: space, isEmbedded: true)
                    } label: {
                        Label(tr("Mes données"), systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("space-data")
                    .accessibilityLabel(Text(tr("Mes données de l'espace \(space.title)")))
                }
            }
            // Selection, then editing as in the Studio: the same Studio as « Mes widgets ».
            // (The destination is built with every update, even hidden: only with widgets to show.)
            .navigationDestination(isPresented: $customizes) {
                let designs = self.designs
                if !designs.isEmpty {
                    WidgetStudio(request: EditorRequest(designs: designs, isNew: true), isPushed: true) { dismiss() }
                }
            }
            .task(id: selection) {
                for design in designs { await model.prepare(design) }
            }
            #if DEBUG
            .onAppear {
                // Test captures: several widgets selected, or a size chosen, or the Studio already open.
                guard !appliedCaptureOptions else { return }
                appliedCaptureOptions = true
                let defaults = UserDefaults.standard
                if let raw = defaults.string(forKey: "screenshotCreatorFormat"), let size = WidgetFormat(rawValue: raw) {
                    setFormat(size)
                } else if defaults.bool(forKey: "screenshotCreatorMulti") {
                    selection = Array(kinds.prefix(3))
                }
                if defaults.bool(forKey: "screenshotCreatorStudio") {
                    // Once the creator is on screen and its size applied.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(900))
                        customizes = true
                    }
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
                Text(tr("Crée ton widget"))
                    .font(.title3.weight(.semibold))
                Text(tr("Choisis une taille et tes widgets, puis personnalise-les dans le Studio."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(tr("Taille"), selection: Binding(get: { format }, set: { setFormat($0) })) {
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
        case .small: tr("L'essentiel en un coup d'œil. Choisis-en plusieurs pour créer plusieurs petits widgets.")
        case .medium: tr("Plus d'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte.")
        case .large: tr("Un tableau de bord de l'espace : un widget en grand, ou jusqu'à 4 widgets réunis.")
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
        .overlay(alignment: .topLeading) {
            if showsExample { ExampleBadge().padding(12) }
        }
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
                    Text(tr("Réunit : \(design.options.parts.map(\.name).joined(separator: " · "))"))
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

    private var widgetsSection: some View {
        EditorSection(title: tr("Widgets"), detail: widgetsDetail) {
            if kinds.contains(where: \.isInteractive) {
                Toggle(isOn: $onlyInteractive.animation(.snappy)) {
                    HStack(spacing: 6) {
                        InteractiveBadge()
                        Text(tr("Seulement les widgets interactifs"))
                            .font(.subheadline)
                    }
                }
                .tint(.accentColor)
                .accessibilityIdentifier("builder-interactive-filter")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 14) {
                ForEach(kinds.filter { !onlyInteractive || $0.isInteractive || selection.contains($0) }) { kind in
                    kindCell(kind)
                }
            }
            Text("\(Image(systemName: "hand.tap.fill")) Interactif : s'utilise depuis l'écran d'accueil, sans ouvrir l'app (valider, cocher, ajouter, scanner).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        let count = Fmt.plural(selection.count, tr("sélectionné"), tr("sélectionnés"))
        return format == .small ? count : tr("\(count) · \(Composer.maxCount(for: format)) au plus")
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
                    if kind.isInteractive {
                        InteractiveBadge()
                    }
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

    private var continueBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptics.tap()
                customizes = true
            } label: {
                Label(continueTitle, systemImage: "paintbrush.pointed")
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .disabled(designs.isEmpty)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .accessibilityIdentifier("creator-continue")
        }
        .background(.bar)
    }

    private var continueTitle: String {
        if format == .small && selection.count > 1 { return tr("Personnaliser les \(selection.count) widgets") }
        return tr("Personnaliser le widget")
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
        }
    }
}
