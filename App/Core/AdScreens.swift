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
        case "ad-studio-tt-style":
            AdStudioStyleView()
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
private struct AdStudioStyleView: View {
    var body: some View {
        let adDesign = WidgetDesign(kind: .timetable, themeID: .dark, format: .large)
        let adRequest = EditorRequest(design: adDesign, isNew: true, section: "style")
        NavigationStack {
            WidgetStudio(request: adRequest, isPushed: false, onClose: {})
        }
    }
}
// ATELIER:VIEWS:END
#endif
