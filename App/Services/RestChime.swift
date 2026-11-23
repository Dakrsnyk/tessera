import AVFoundation
import AudioToolbox
import Foundation
import UIKit

/// The end of a rest while Ardane is open (2026-11-23): the « ding » of Ardane and two strong vibrations (one per note),
/// so the person knows the next set is due without looking at the phone. On silent, the ding is muted by the switch
/// (`.ambient`, which also plays over the person's music instead of stopping it) and the vibrations remain. The first
/// version used `AudioServicesPlayAlertSound` with the sound file: nothing was heard nor felt on the iPhone (2026-11-23).
/// App in the background or screen locked, `RestNotifier`'s notification carries the same sound (iOS vibrates on silent
/// too); in front, that notification stays quiet (`NotificationPresenter`), so the rest never rings twice.
@MainActor
final class RestChime {
    static let shared = RestChime()

    /// A wake-up later than this after the end says nothing (the iPhone was busy: better silent than late).
    static let lateness: TimeInterval = 3

    private var task: Task<Void, Never>?
    private var armedEnd: Date?
    private var player: AVAudioPlayer?

    /// Follows the workout: armed for the rest running, disarmed when it is passed, paused or the session ends.
    /// Safe to call after every change.
    func follow(_ state: FitnessState, now: Date = Date()) {
        let end = RestNotifier.pendingEnd(state, now: now)
        guard end != armedEnd else { return }
        task?.cancel()
        task = nil
        armedEnd = end
        guard let end else { return }
        task = Task { [weak self] in
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            self?.ring(for: end)
        }
    }

    /// The app in the background: disarmed, the notification rings instead. Back in front, `follow` arms again
    /// the rest still running; a rest that ended meanwhile never rings a second time.
    func disarm() {
        task?.cancel()
        task = nil
        armedEnd = nil
    }

    /// In front (active, or inactive under the Notification Center or a call: the notification is kept quiet then too).
    static func shouldRing(end: Date, now: Date, isInBackground: Bool) -> Bool {
        !isInBackground && now.timeIntervalSince(end) >= -0.5 && now.timeIntervalSince(end) <= lateness
    }

    private func ring(for end: Date) {
        armedEnd = nil
        task = nil
        guard Self.shouldRing(end: end, now: Date(), isInBackground: UIApplication.shared.applicationState == .background) else { return }
        playDing()
        // Two vibrations, on the two notes (D5, then A5 half a second later).
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    /// The ding through an `.ambient` audio session: muted by the silent switch, mixed with the music playing.
    private func playDing() {
        if player == nil {
            let name = (RestNotifier.soundFile as NSString).deletingPathExtension
            let ext = (RestNotifier.soundFile as NSString).pathExtension
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient)
        try? session.setActive(true)
        player?.currentTime = 0
        player?.play()
    }
}
