import SwiftUI
import WidgetKit

/// Real point sizes of widgets on a 6.1" iPhone, used to draw previews at true proportions.
enum WidgetMetrics {
    static func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        case .systemLarge, .systemExtraLarge: CGSize(width: 364, height: 382)
        case .accessoryCircular: CGSize(width: 72, height: 72)
        case .accessoryRectangular: CGSize(width: 172, height: 76)
        case .accessoryInline: CGSize(width: 250, height: 24)
        @unknown default: CGSize(width: 170, height: 170)
        }
    }

    static let cornerRadius: CGFloat = 22
}

/// Draws a design exactly as WidgetKit would, scaled to the width available.
struct WidgetPreview: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let payload: WidgetPayload
    var width: CGFloat?
    var date = Date()

    var body: some View {
        let size = WidgetMetrics.size(family)
        Group {
            if let width {
                scaled(size: size, scale: width / size.width)
            } else {
                // Fills the width offered by the parent while keeping the widget's proportions.
                Color.clear
                    .aspectRatio(size.width / size.height, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        GeometryReader { geo in
                            scaled(size: size, scale: geo.size.width / size.width)
                        }
                    }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Aperçu du widget \(design.name)"))
    }

    private func scaled(size: CGSize, scale: CGFloat) -> some View {
        canvas
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
    }

    @ViewBuilder private var canvas: some View {
        let size = WidgetMetrics.size(family)
        let widget = WidgetCanvas(design: design, family: family, date: date, payload: payload, isPremium: true, isInteractive: false)
            .frame(width: size.width, height: size.height)
        if family.isAccessory {
            widget
                .foregroundStyle(.white)
                .environment(\.colorScheme, .dark)
                .padding(family == .accessoryInline ? 0 : 6)
                .background {
                    if family == .accessoryCircular {
                        Circle().fill(.white.opacity(0.16))
                    } else if family == .accessoryRectangular {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.16))
                    }
                }
        } else {
            widget
                .background(DesignBackground(design: design))
                .clipShape(RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

struct PremiumBadge: View {
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
            if !compact { Text("Premium") }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.premiumInk)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, 3)
        .background(Color.premiumFill, in: Capsule())
        .accessibilityLabel(Text("Premium"))
    }
}

extension Color {
    static let premiumFill = Color(light: "F6E7B8", dark: "4A3B12")
    static let premiumInk = Color(light: "7A5500", dark: "F2D27A")
    static let cardFill = Color(uiColor: .secondarySystemGroupedBackground)
    static let screenFill = Color(uiColor: .systemGroupedBackground)
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.medium))
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

/// Tappable preview of a catalog template.
struct TemplateCard: View {
    let template: WidgetTemplate
    var width: CGFloat?
    var isPremiumUser: Bool

    var body: some View {
        let design = template.makeDesign()
        VStack(alignment: .leading, spacing: 8) {
            WidgetPreview(design: design, family: .systemSmall, payload: SamplePayload.make(for: design), width: width)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(template.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if template.isPremium && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Ouvre l'éditeur"))
    }
}

/// Card for a saved design in "Mes widgets".
struct DesignCard: View {
    let design: WidgetDesign
    let payload: WidgetPayload
    var width: CGFloat?
    let isPremiumUser: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                WidgetPreview(design: design, family: .systemSmall, payload: payload, width: width)
                if design.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(8)
                }
            }
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(design.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(design.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if design.usesPremiumFeatures && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
