import SwiftUI

// Accessibility helpers shared by the screens: a 44 pt touch target, a readable ink on a brand color, and one
// check circle (label, value and trait for VoiceOver).

extension View {
    /// A touch target of at least 44 × 44 pt (HIG), without changing what is drawn: the content stays centered.
    func tapTarget(_ minimum: CGFloat = 44) -> some View {
        frame(minWidth: minimum, minHeight: minimum)
            .contentShape(Rectangle())
    }

    /// Enlarges the touch area by `amount` pt on each side without moving anything (for a button in a bar or a capsule
    /// whose height must not change): 36 pt tall + 4 = 44 pt.
    func tapAreaOutset(_ amount: CGFloat = 4) -> some View {
        contentShape(Rectangle().inset(by: -amount))
    }
}

extension View {
    /// Asks before a definitive deletion of data the user typed (a context menu has no undo). The dialog is shown as long
    /// as `item` holds something; `perform` receives it when the user confirms.
    func confirmDelete<Item>(
        _ item: Binding<Item?>,
        title: String,
        button: String,
        message: String,
        perform: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: item.wrappedValue
        ) { value in
            Button(button, role: .destructive) { perform(value) }
        } message: { _ in
            Text(message)
        }
    }
}

extension Color {
    /// The ink (text or icon) to put on the color `hex`. White stays the choice while it reads at 4.5:1 and the
    /// dark ink is not clearly better; on a light color (orange, turquoise, pink) the ink turns dark, so the brand color
    /// itself never changes.
    static func readableInk(on hex: String) -> Color {
        let luminance = ColorMath.luminance(hex)
        let whiteContrast = 1.05 / (luminance + 0.05)
        // Dark ink 141414 (luminance about 0.007).
        let darkContrast = (luminance + 0.05) / 0.057
        if whiteContrast >= 4.5 || darkContrast < whiteContrast * 1.15 { return .white }
        return Color(hex: "141414")
    }
}

/// The check circle of a task: 44 pt target, a name and its state read by VoiceOver (« Fait » / « À faire »).
/// The caller sets the button style (`.borderless` in a list row, `.pressable` elsewhere).
struct CheckCircleButton: View {
    let isDone: Bool
    /// What is checked (the title of the task).
    let label: String
    var doneColor: Color = .accentColor
    var todoColor: Color = .secondary
    var font: Font = .title3
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(font)
                .foregroundStyle(isDone ? doneColor : todoColor)
                .tapTarget()
        }
        .accessibilityLabel(label)
        .accessibilityValue(isDone ? tr("Fait") : tr("À faire"))
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }
}
