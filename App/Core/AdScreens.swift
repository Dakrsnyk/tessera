import SwiftUI

#if DEBUG
/// Demo screens added for the ad captures by the workshop of the marketing HQ (ardane-hq, `server/atelier.js`).
/// `-screenshotScreen ad-<name>` shows the screen alone, over the demo data seeded by `ScreenshotMode`
/// (see `WidgetGalleryView`). The HQ only ever edits this file, and only between the markers below: one
/// `case "ad-<name>":` per screen, and the small views these screens need. Test builds only
/// (`scripts/check_swift.py` checks that `AdScreens` is never used outside `#if DEBUG`).
enum AdScreens {
    /// Every screen added by the workshop is named `ad-<name>`.
    static let prefix = "ad-"

    @MainActor @ViewBuilder
    static func view(named name: String) -> some View {
        switch name {
        // ATELIER:BEGIN
        case "ad-studies-timetable":
            NavigationStack {
                StudiesTimetablePage()
            }
        // ATELIER:END
        default:
            // A name the HQ has not added: said on screen, so that a capture never passes for a real screen.
            Text(verbatim: "Unknown ad screen: \(name)")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

// ATELIER:VIEWS:BEGIN
// ATELIER:VIEWS:END
#endif
