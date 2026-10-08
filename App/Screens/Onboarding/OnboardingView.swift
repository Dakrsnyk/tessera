import SwiftUI
import WidgetKit

/// The first launch: the look of the app, then who the user is and what they care about, then only the
/// questions that matter for those interests. Every step can be skipped, nothing is required, and each
/// answer is saved as it is given (see `UserProfile`), so leaving halfway loses nothing.
struct OnboardingView: View {
    /// Only the style step (installs from before the styles existed).
    var styleOnly = false
    /// Only the questions about the user (installs from before « Mes informations »).
    var personalizationOnly = false
    let onFinish: () -> Void
    @Environment(AppModel.self) private var model
    @State private var step: Step?
    @State private var goesBack = false

    enum Step: Hashable {
        case style, identity, interests
        case topic(ProfileTopic)
    }

    /// The steps, recomputed as interests are picked: a page per topic they lead to.
    private var steps: [Step] {
        if styleOnly { return [.style] }
        let personal: [Step] = [.identity, .interests] + model.profile.topics.map(Step.topic)
        return personalizationOnly ? personal : [.style] + personal
    }

    private var current: Step { step ?? steps[0] }
    private var index: Int { steps.firstIndex(of: current) ?? 0 }
    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        ZStack {
            switch current {
            case .style:
                StyleStep(isLast: styleOnly) { advance() }
                    .transition(.opacity)
            default:
                personalStep
                    .id(current)
                    .transition(.asymmetric(
                        insertion: .move(edge: goesBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: goesBack ? .trailing : .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: current)
        #if DEBUG
        .onAppear(perform: applyCaptureStep)
        #endif
    }

    private func advance() {
        Haptics.tap()
        if isLast {
            onFinish()
            return
        }
        goesBack = false
        step = steps[index + 1]
    }

    private func goBack() {
        guard index > 0 else { return }
        goesBack = true
        step = steps[index - 1]
    }

    /// « Passer »: a topic left without any answer is remembered as « à compléter ».
    private func skip() {
        if case let .topic(topic) = current, model.facts(for: topic).isEmpty, !model.profile.skippedTopics.contains(topic) {
            model.update(\.profile) { $0.skippedTopics.append(topic) }
        }
        advance()
    }

    // MARK: The personal steps

    private var personalStep: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch current {
                    case .identity: IdentityStep()
                    case .interests: InterestsStep()
                    case let .topic(topic): TopicStep(topic: topic)
                    case .style: EmptyView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button(action: advance) {
                    Text(isLast ? tr("C'est parti") : tr("Continuer"))
                        .font(.headline)
                        .foregroundStyle(.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .accessibilityIdentifier("onboarding-continue")
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.screenFill)
            }
        }
        .background(.screenGradient)
    }

    private var topBar: some View {
        let personal = steps.filter { $0 != .style }
        let position = personal.firstIndex(of: current) ?? 0
        return HStack(spacing: 14) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .opacity(index > 0 ? 1 : 0)
            .disabled(index == 0)
            .accessibilityLabel(Text(tr("Retour", context: "back")))
            HStack(spacing: 5) {
                ForEach(personal.indices, id: \.self) { item in
                    Capsule()
                        .fill(item <= position ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 5)
                }
            }
            .animation(.snappy, value: position)
            .accessibilityElement()
            .accessibilityLabel(Text(tr("Étape \(position + 1) sur \(personal.count)")))
            Button(tr("Passer"), action: skip)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("onboarding-skip")
        }
        .padding(.horizontal, 12)
    }

    #if DEBUG
    /// Test captures: `-screenshotScreen onboarding-identity`, `onboarding-interests` or `onboarding-sport`.
    private func applyCaptureStep() {
        guard let screen = ScreenshotMode.screen, screen.hasPrefix("onboarding-") else { return }
        let name = String(screen.dropFirst("onboarding-".count))
        switch name {
        case "identity": step = .identity
        case "interests": step = .interests
        default: if let topic = ProfileTopic(rawValue: name) { step = .topic(topic) }
        }
    }
    #endif
}

/// Step 1: the first name and the name.
private struct IdentityStep: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        let first = model.settings.profileName.trimmed
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(
                symbol: "hand.wave.fill", colorHex: "F2A33A",
                title: tr("Comment veux-tu qu'on t'appelle ?"),
                message: tr("Ton prénom sert au message d'accueil. Tout reste sur ton iPhone.")
            )
            VStack(spacing: 10) {
                ProfileTextField(
                    placeholder: tr("Prénom"),
                    text: Binding(get: { model.settings.profileName }, set: { name in model.updateSettings { $0.profileName = name } }),
                    identifier: "identity-first-name"
                )
                .textContentType(.givenName)
                .focused($focused)
                ProfileTextField(
                    placeholder: tr("Nom (facultatif)"),
                    text: Binding(get: { model.profile.lastName }, set: { name in model.update(\.profile) { $0.lastName = name } }),
                    identifier: "identity-last-name"
                )
                .textContentType(.familyName)
            }
            .card(padding: 12)
            if !first.isEmpty {
                // What the Home tab will say.
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                    Text(tr("Bonjour \(first.split(separator: " ").first.map(String.init) ?? first)"))
                        .font(.title3.weight(.semibold))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: first.isEmpty)
        .onAppear { focused = model.settings.profileName.isEmpty }
    }
}

/// Step 2: the interests. They decide the next pages, and what Tessera puts forward.
private struct InterestsStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(
                symbol: "square.grid.2x2.fill", colorHex: "8C6CFF",
                title: tr("Qu'est-ce qui t'intéresse ?"),
                message: tr("Choisis-en autant que tu veux. Tessera ne posera que les questions utiles, et tu pourras tout changer plus tard.")
            )
            InterestGrid(selection: Binding(
                get: { model.profile.interests },
                set: { interests in model.update(\.profile) { $0.interests = interests } }
            ))
        }
    }
}

/// Step 3: one page per topic, only for the interests picked.
private struct TopicStep: View {
    let topic: ProfileTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(symbol: topic.symbol, colorHex: topic.colorHex, title: topic.title, message: topic.purpose)
            TopicForm(topic: topic)
            Text(tr("Tout est facultatif : laisse vide ce que tu préfères ne pas dire."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StepTitle: View {
    let symbol: String
    let colorHex: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color(hex: colorHex), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}

/// First step: the look of the app. Everything on this screen changes as soon as a style is picked.
private struct StyleStep: View {
    let isLast: Bool
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let style = AppStyle.style(model.settings.appStyle)
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    TesseraMark(size: 40)
                    Text(isLast ? tr("Nouveau : les styles") : tr("Bienvenue dans Tessera"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(tr("Choisis ton style"))
                        .font(.largeTitle.weight(.bold))
                    Text(tr("Dix ambiances, chacune en clair et en sombre. Tu pourras en changer à tout moment dans Réglages."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.top, 20)
                StylePreviewPair(style: style, height: 206)
                    .padding(.horizontal, 30)
                    .animation(.easeInOut(duration: 0.2), value: style.id)
                AppStyleGrid()
                AppearancePicker()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text(isLast ? tr("C'est parti") : tr("Continuer"))
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .background(style.screen)
        }
        .background(style.screen.ignoresSafeArea())
    }
}

struct AddStepRow: View {
    let number: Int
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Étape \(number)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PerkRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
