import SwiftUI
import UIKit

/// A card held then moved, as the edit mode of Mon Quotidien receives it: where the finger took the card (in the
/// card) and how far it went since, in the grid (the scroll of Home during the drag included).
struct DailyCardDrag: Equatable {
    var grab: CGPoint
    var translation: CGSize
}

/// The hold-then-move of a card in edit mode, done by UIKit like the Home Screen of the iPhone: a long press of half
/// a second that fails as soon as the finger moves, so a swipe scrolls Home as usual and only a real hold picks the
/// card up. Once it is up, Home no longer scrolls under the finger, and it scrolls by itself when the card nears
/// the top or the bottom of the screen.
/// SwiftUI's long press + drag sequence fought with the scroll of Home in edit mode (remark of 2026-11-05 on
/// Build 340: « j'ai du mal à défiler vers le haut ou le bas »).
struct DailyHoldToMove: UIViewRepresentable {
    var onMove: (DailyCardDrag) -> Void
    var onDrop: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        press.minimumPressDuration = 0.5
        press.allowableMovement = 10
        view.addGestureRecognizer(press)
        context.coordinator.update(onMove: onMove, onDrop: onDrop)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.update(onMove: onMove, onDrop: onDrop)
    }

    /// The card goes away while up (the edit mode ended, the card left Mon Quotidien): Home scrolls again at once;
    /// the drop waits for the end of the view update (no change of state during it), and does nothing once the
    /// mode has ended.
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.finish(drop: false, dropLater: true)
    }

    @MainActor
    final class Coordinator: NSObject {
        /// One card up at a time: a second finger holding another card is ignored (weak: a coordinator that goes
        /// away never blocks the next one).
        private static weak var lifted: Coordinator?
        private var onMove: (DailyCardDrag) -> Void = { _ in }
        private var onDrop: () -> Void = {}
        private var active = false
        /// The scroll view of Home (the nearest one around the card), scrolled by the drag near the edges.
        private weak var scroll: UIScrollView?
        /// The pans of the scroll views around the card, turned off while the card is up.
        private var frozen: [UIPanGestureRecognizer] = []
        private var grab: CGPoint = .zero
        /// Where the finger started and where it is, in the window.
        private var start: CGPoint = .zero
        private var finger: CGPoint = .zero
        private var startOffset: CGFloat = 0
        private var link: CADisplayLink?

        func update(onMove: @escaping (DailyCardDrag) -> Void, onDrop: @escaping () -> Void) {
            self.onMove = onMove
            self.onDrop = onDrop
        }

        @objc func handle(_ press: UILongPressGestureRecognizer) {
            guard let view = press.view else { return }
            switch press.state {
            case .began:
                guard Self.lifted == nil else {
                    // Turning the recognizer off and on cancels this press (it was never active: nothing to undo).
                    press.isEnabled = false
                    press.isEnabled = true
                    return
                }
                Self.lifted = self
                active = true
                grab = press.location(in: view)
                start = press.location(in: nil)
                finger = start
                freezeScrolling(around: view)
                startOffset = scroll?.contentOffset.y ?? 0
                // The link holds its target strongly: a weak relay, so the coordinator never stays alive through it.
                let relay = LinkRelay()
                relay.owner = self
                let link = CADisplayLink(target: relay, selector: #selector(LinkRelay.tick(_:)))
                link.add(to: .main, forMode: .common)
                self.link = link
                send()
            case .changed:
                finger = press.location(in: nil)
                send()
            default:
                finish(drop: true)
            }
        }

        /// The finger leaves (or the card goes away): Home scrolls again, the card is dropped (now, or once the
        /// current view update is over).
        func finish(drop: Bool, dropLater: Bool = false) {
            guard active else { return }
            active = false
            if Self.lifted === self { Self.lifted = nil }
            link?.invalidate()
            link = nil
            frozen.forEach { $0.isEnabled = true }
            frozen = []
            scroll = nil
            if drop {
                onDrop()
            } else if dropLater {
                let onDrop = onDrop
                DispatchQueue.main.async { onDrop() }
            }
        }

        private func send() {
            let scrolled = (scroll?.contentOffset.y ?? startOffset) - startOffset
            onMove(DailyCardDrag(grab: grab, translation: CGSize(width: finger.x - start.x,
                                                                 height: finger.y - start.y + scrolled)))
        }

        /// Turns off the pans of the scroll views around the card (turning one off also stops a scroll it had begun).
        private func freezeScrolling(around view: UIView) {
            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? UIScrollView {
                    if scroll == nil { scroll = scrollView }
                    if scrollView.panGestureRecognizer.isEnabled {
                        scrollView.panGestureRecognizer.isEnabled = false
                        frozen.append(scrollView.panGestureRecognizer)
                    }
                }
                ancestor = current.superview
            }
        }

        /// Near the top or the bottom of the visible part of Home, Home scrolls, faster as the finger gets closer
        /// to the edge; the card stays under the finger. The speed is per second, the same at 60 and at 120 Hz.
        fileprivate func tick(_ link: CADisplayLink) {
            guard active, let scroll else { return }
            let visible = scroll.convert(scroll.bounds, to: nil)
            let top = visible.minY + scroll.adjustedContentInset.top
            let bottom = visible.maxY - scroll.adjustedContentInset.bottom
            let edge: CGFloat = 80
            let frame = min(max(link.targetTimestamp - link.timestamp, 1.0 / 120), 1.0 / 30)
            let fastest = 840 * CGFloat(frame)
            var step: CGFloat = 0
            if finger.y < top + edge {
                step = -min(1, (top + edge - finger.y) / edge) * fastest
            } else if finger.y > bottom - edge {
                step = min(1, (finger.y - (bottom - edge)) / edge) * fastest
            }
            guard step != 0 else { return }
            let lowest = -scroll.adjustedContentInset.top
            let highest = max(lowest, scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height)
            let next = min(max(scroll.contentOffset.y + step, lowest), highest)
            guard abs(next - scroll.contentOffset.y) > 0.01 else { return }
            scroll.contentOffset = CGPoint(x: scroll.contentOffset.x, y: next)
            send()
        }
    }
}

/// The target of the display link of `DailyHoldToMove`: holds the coordinator weakly (a link holds its target
/// strongly until it is invalidated).
@MainActor
private final class LinkRelay: NSObject {
    weak var owner: DailyHoldToMove.Coordinator?

    @objc func tick(_ link: CADisplayLink) {
        guard let owner else {
            link.invalidate()
            return
        }
        owner.tick(link)
    }
}
