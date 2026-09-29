import SwiftUI

/// The forms of a space (a food, a workout, an expense…), presented by the space's list itself.
///
/// A `.sheet` written on a list section is copied onto each of its rows, and those rows are rebuilt as
/// soon as the data changes: a food logged, a routine saved, a set done. When the space is open inside
/// the widget editor or the space creator, closing a form whose rows were rebuilt could close the sheet
/// underneath as well, and the widget being made was lost. Presented from the list, a form has one
/// presenter that never changes, and closing it only ever closes the form.
@MainActor
@Observable
final class SpaceSheets {
    struct Sheet: Identifiable {
        let id = UUID()
        let content: AnyView
    }

    var current: Sheet?

    func open<Content: View>(@ViewBuilder _ content: () -> Content) {
        current = Sheet(content: AnyView(content()))
    }
}

private struct SpaceSheetHost: ViewModifier {
    @State private var sheets = SpaceSheets()

    func body(content: Content) -> some View {
        content
            .environment(sheets)
            .sheet(item: $sheets.current) { sheet in
                sheet.content
            }
    }
}

extension View {
    /// Presents the forms opened from the rows inside (see `SpaceSheets`).
    func hostsSpaceSheets() -> some View {
        modifier(SpaceSheetHost())
    }
}
