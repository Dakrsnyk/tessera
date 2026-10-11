import SwiftUI
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
            .background(.screenGradient)
            .screenshotScroll()
            // Only the profile, at the top right: no title, no search.
            .navigationBarTitleDisplayMode(.inline)
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
                case let .infoArea(area): InfoAreaView(area: area)
                case let .app(app): MiniAppView(app: app)
                case let .page(page): MiniAppPageView(page: page)
                }
            }
            .task {
                // « Mon Quotidien » shows the weather and today's events when they are available.
                model.refreshEvents()
                await model.refreshWeather()
            }
            .toolbar {
                // The date, on the same line as the profile, in the app style's color.
                ToolbarItem(placement: .topBarLeading) {
                    Text(Fmt.longDay(Date()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("home-date")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.isProfilePresented = true
                    } label: {
                        ProfileAvatar(name: model.settings.profileName.trimmed, size: 32)
                            .tutorialTarget(.profile)
                    }
                    .accessibilityLabel(Text(tr("Profil et réglages")))
                }
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                DailySection()
                    .id(TutorialTarget.daily.rawValue)
                    .tutorialTarget(.daily)
                MyInfoCard()
                    .id(TutorialTarget.info.rawValue)
                    .tutorialTarget(.info)
                if !model.isPremium {
                    PremiumBanner { router.isPaywallPresented = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .background(alignment: .top) { Color.clear.frame(height: 1).id("home-top") }
        }
        // Home scrolls up and down only: never sideways, never a sideways bounce.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func bringIntoView(_ step: TutorialStep?, proxy: ScrollViewProxy) {
        guard let step, step.tab == .home else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            if let target = step.target, target == .info {
                proxy.scrollTo(target.rawValue, anchor: UnitPoint(x: 0.5, y: 0.04))
            } else {
                proxy.scrollTo("home-top", anchor: .top)
            }
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
                    .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Ardane Premium"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tr("\(WidgetKind.allCases.filter { $0.isPremium }.count) widgets en plus, \(ThemeCatalog.all.count - ThemeCatalog.free.count) styles, analyses et fonds photo."))
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
        .buttonStyle(.plain)
    }
}
