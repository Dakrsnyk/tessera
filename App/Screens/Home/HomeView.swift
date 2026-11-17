import SwiftUI
import UIKit
import WidgetKit

/// Home: the person's own figures and information only, « Mon Quotidien » (which leads to every
/// mini-app) and « Mes informations ». Mes widgets and the Store are in the tab bar.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.homePath) {
            ScrollViewReader { proxy in
                scrollContent
                    // The tutorial brings what it talks about near the top, above its card.
                    .onChange(of: router.tutorialStep) { _, step in bringIntoView(step, proxy: proxy) }
            }
            .cristalScreen()
            .screenshotScroll()
            // No title, no search: the date and the profile sit in a glass capsule at the top of the page, so the bar stays hidden here.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case let .space(space):
                    // A space with its mini-app opens the mini-app; the others show their data.
                    if let app = MiniApp(space: space), app.isBuilt {
                        MiniAppView(app: app)
                    } else {
                        SpaceView(space: space, isEmbedded: true)
                    }
                case .info: MyInfoView()
                case let .infoArea(area):
                    // Old links only: the page per category is gone, its mini-app (or space) takes over.
                    if let app = area.miniApp {
                        MiniAppView(app: app)
                    } else if let space = area.space {
                        SpaceView(space: space, isEmbedded: true)
                    } else {
                        MyInfoView()
                    }
                case let .app(app): MiniAppView(app: app)
                case let .page(page): MiniAppPageView(page: page)
                }
            }
            .task {
                // « Mon Quotidien » shows today's events when they are available.
                model.refreshEvents()
            }
        }
    }

    /// The date and the profile on one glass capsule, the first thing on the page (the design's top bar).
    private var topCapsule: some View {
        HStack(spacing: 8) {
            Text(Fmt.longDay(Date()))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home-date")
            Spacer(minLength: 8)
            Button {
                router.isProfilePresented = true
            } label: {
                ProfileAvatar(name: model.settings.profileName.trimmed, size: 36)
                    .tutorialTarget(.profile, radius: 18)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(tr("Profil et réglages")))
        }
        .padding(.leading, 18)
        .padding(.trailing, 5)
        .frame(minHeight: 46)
        .cristalGlass(in: Capsule())
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 18) {
                    topCapsule
                    DailySection()
                        .id(TutorialTarget.daily.rawValue)
                        .tutorialTarget(.daily)
                }
                MyInfoCard()
                if !model.isPremium {
                    PremiumBanner { router.isPaywallPresented = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
            // Never wider than the screen, whatever a card asks for (long English or German texts, big text).
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(alignment: .top) { Color.clear.frame(height: 1).id("home-top") }
            // Last safety net: the scroll view under Home can never move sideways.
            .background { HorizontalScrollLock().frame(width: 1, height: 1).allowsHitTesting(false) }
            // The tutorial scrolls what it lights up whole into place.
            .tutorialScroll(step: router.tutorialStep, tab: .home)
        }
        // Home scrolls up and down only: never sideways, never a sideways bounce.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func bringIntoView(_ step: TutorialStep?, proxy: ScrollViewProxy) {
        guard let step, step.tab == .home else { return }
        // Back to the top at once (no animation); then `tutorialScroll` brings the part of the step to its place.
        proxy.scrollTo("home-top", anchor: .top)
    }

}

/// Finds the UIScrollView that holds Home and forbids any sideways movement: no horizontal bounce,
/// directional lock, and the horizontal offset is put back at once if anything ever moves it
/// (a card wider than the screen used to let the whole page slide left or right).
private struct HorizontalScrollLock: UIViewRepresentable {
    func makeUIView(context: Context) -> LockView { LockView() }
    func updateUIView(_ view: LockView, context: Context) { view.lock() }

    final class LockView: UIView {
        private var observation: NSKeyValueObservation?
        private weak var locked: UIScrollView?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            lock()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            lock()
        }

        func lock() {
            var candidate = superview
            while let view = candidate, !(view is UIScrollView) { candidate = view.superview }
            guard let scroll = candidate as? UIScrollView else { return }
            scroll.alwaysBounceHorizontal = false
            scroll.isDirectionalLockEnabled = true
            scroll.showsHorizontalScrollIndicator = false
            guard scroll !== locked else { return }
            locked = scroll
            Self.pin(scroll)
            observation = scroll.observe(\.contentOffset, options: []) { scroll, _ in
                MainActor.assumeIsolated { Self.pin(scroll) }
            }
        }

        /// The only horizontal offset allowed: the one of the safe area (zero in portrait).
        private static func pin(_ scroll: UIScrollView) {
            let x = -scroll.adjustedContentInset.left
            guard abs(scroll.contentOffset.x - x) > 0.01 else { return }
            scroll.contentOffset = CGPoint(x: x, y: scroll.contentOffset.y)
        }
    }
}

struct PremiumBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.premiumInk)
                    .frame(width: 48, height: 48)
                    .background(Color.premiumFill, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Ardane Premium"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tr("\(WidgetKind.offered.filter { $0.isPremium }.count) widgets en plus, \(ThemeCatalog.all.count - ThemeCatalog.free.count) styles, analyses et fonds photo."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.pressable)
    }
}
