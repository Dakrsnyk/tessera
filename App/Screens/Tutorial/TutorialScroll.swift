import SwiftUI
import UIKit

extension View {
    /// Put on the content of a tab's vertical scroll view: when the tutorial shows a step of that tab, the content is
    /// scrolled so the part the step lights up sits whole in the middle of the room above the card.
    /// `step` is passed in so the view updates when the step changes.
    func tutorialScroll(step: TutorialStep?, tab: Router.Tab) -> some View {
        background {
            TutorialScrollDriver(step: step, tab: tab)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Finds the UIScrollView that holds the tab and moves it, using the pure rules of `TutorialLayout`.
private struct TutorialScrollDriver: UIViewRepresentable {
    let step: TutorialStep?
    let tab: Router.Tab

    func makeUIView(context: Context) -> DriverView { DriverView() }
    func updateUIView(_ view: DriverView, context: Context) { view.update(step: step, tab: tab) }

    final class DriverView: UIView {
        private var lastStep: TutorialStep?
        private var task: Task<Void, Never>?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { nil }

        func update(step: TutorialStep?, tab: Router.Tab) {
            guard step != lastStep else { return }
            lastStep = step
            task?.cancel()
            guard let step, step.tab == tab, !step.targets.isEmpty else { return }
            task = Task { @MainActor [weak self] in
                // Once the tab is shown and laid out, and the parts have reported where they are.
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                self?.scroll(for: step)
            }
        }

        private func enclosingScrollView() -> UIScrollView? {
            var candidate = superview
            while let view = candidate, !(view is UIScrollView) { candidate = view.superview }
            return candidate as? UIScrollView
        }

        private func scroll(for step: TutorialStep) {
            guard let window, let scroll = enclosingScrollView() else { return }
            let candidates = step.targets.map { TutorialFrames.shared.candidate(for: $0) }
            let card = CGSize(width: min(520, window.bounds.width - 28), height: TutorialFrames.shared.cardHeight)
            guard let move = TutorialLayout.scrollDelta(
                candidates: candidates, screen: window.bounds.size,
                safeTop: window.safeAreaInsets.top, safeBottom: window.safeAreaInsets.bottom, card: card
            ) else { return }
            let lowest = -scroll.adjustedContentInset.top
            let highest = max(lowest, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let wanted = min(max(scroll.contentOffset.y + move.delta, lowest), highest)
            guard abs(wanted - scroll.contentOffset.y) > 0.5 else { return }
            scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: wanted), animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }
}
