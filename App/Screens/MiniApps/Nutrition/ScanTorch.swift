import AVFoundation
import Observation
import SwiftUI

/// How the light of the scanner works, as in the iPhone's own camera: by itself when it is dark, always, or never.
/// The choice is kept from one scan to the next.
enum ScanFlashMode: String, CaseIterable, Identifiable {
    case auto, on, off
    var id: String { rawValue }

    /// The next choice when the button is touched: automatic, on, off, and back to automatic.
    var next: ScanFlashMode {
        switch self {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
    }

    var title: String {
        switch self {
        case .auto: tr("Flash automatique")
        case .on: tr("Flash activé")
        case .off: tr("Flash désactivé")
        }
    }

    static let key = "tessera.scanFlashMode"

    /// The choice kept on this iPhone; automatic until the person chooses.
    static func saved(in defaults: UserDefaults = .standard) -> ScanFlashMode {
        defaults.string(forKey: key).flatMap(ScanFlashMode.init(rawValue:)) ?? .auto
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.key)
    }
}

/// Is it too dark to scan? Pure rules on the exposure the camera chose by itself (its sensitivity, its exposure
/// time, its aperture): no image is looked at.
enum ScanLight {
    /// Under this exposure value (at ISO 100) the light comes on: about 14 lux, a dim room in the evening.
    static let darkExposureValue = 2.5
    /// A camera whose sensitivity stops before that value says it another way: it is under its own target
    /// (`underexposedOffset` stops or more) while the scene is already dim (`dimExposureValue`, about 40 lux).
    static let dimExposureValue = 4.0
    static let underexposedOffset: Float = -1

    /// The exposure value of the scene at ISO 100. Nil when a reading can't be used (a camera that isn't running).
    static func exposureValue(iso: Float, seconds: Double, aperture: Float) -> Double? {
        guard iso.isFinite, seconds.isFinite, aperture.isFinite, iso > 0, seconds > 0, aperture > 0 else { return nil }
        return log2(Double(aperture) * Double(aperture) / seconds) - log2(Double(iso) / 100)
    }

    /// Nil when the reading can't be used: nothing is decided on it.
    static func isDark(iso: Float, seconds: Double, aperture: Float, offset: Float) -> Bool? {
        guard let value = exposureValue(iso: iso, seconds: seconds, aperture: aperture) else { return nil }
        if value <= darkExposureValue { return true }
        return offset.isFinite && offset <= underexposedOffset && value <= dimExposureValue
    }
}

/// Several dark readings in a row before the light comes on: a hand passing in front of the lens is not the night.
struct ScanLightMeter {
    static let needed = 3
    private(set) var streak = 0

    /// One more reading; true when the light should come on.
    mutating func feed(_ dark: Bool?) -> Bool {
        streak = dark == true ? streak + 1 : 0
        return streak >= Self.needed
    }

    mutating func reset() { streak = 0 }
}

/// Is this camera really running? The readings of a live camera never stay exactly the same (its measure of the
/// scene moves a little at every image); those of a camera that is not running never move. Used when the scanner's
/// own camera could not be found: nothing is decided on readings that never moved.
struct ScanLiveness {
    private var last: (iso: Float, offset: Float)?
    private(set) var isLive = false

    /// One more reading; true once two readings in a row differed.
    mutating func feed(iso: Float, offset: Float) -> Bool {
        if let last, last.iso != iso || last.offset != offset { isLive = true }
        last = (iso, offset)
        return isLive
    }

    mutating func reset() {
        last = nil
        isLive = false
    }
}

/// The light of the live scanner (the iPhone's torch, which stays on while a barcode is read and a dish is
/// photographed). In automatic mode it comes on by itself when the camera reports a dark scene, then stays on:
/// its own light makes the scene bright, so the same reading can't turn it off again. The button always wins.
///
/// The scanner's camera belongs to VisionKit: the light is set on the camera it runs (found through its preview),
/// or else on the back camera, whose readings are then believed only once they move (`ScanLiveness`): a doubtful
/// measure never turns the light on. It goes out as soon as the camera stops.
@MainActor
@Observable
final class ScanTorch {
    private(set) var mode: ScanFlashMode
    /// The light is on right now.
    private(set) var isLit = false
    /// False on a device without a light, and in the simulator: the button is then not shown.
    private(set) var isAvailable = false

    /// Half of the full power: enough to read a barcode or light a plate at arm's length, without the glare of the
    /// full torch on a shiny package.
    static let level: Float = 0.5

    @ObservationIgnored private weak var scanner: UIViewController?
    @ObservationIgnored private var sessionDevice: AVCaptureDevice?
    @ObservationIgnored private var meter = ScanLightMeter()
    @ObservationIgnored private var liveness = ScanLiveness()
    @ObservationIgnored private var litByItself = false
    @ObservationIgnored private var watch: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = ScanFlashMode.saved(in: defaults)
    }

    /// The camera is live: the choice is applied, and in automatic mode the light of the scene is watched.
    func start(scanner: UIViewController) {
        self.scanner = scanner
        sessionDevice = nil
        meter.reset()
        liveness.reset()
        litByItself = false
        isAvailable = Self.backCamera()?.hasTorch == true
        watch?.cancel()
        guard isAvailable else { return }
        watch = Task { [weak self] in
            // The camera needs a moment to start and to settle its exposure.
            try? await Task.sleep(for: .milliseconds(700))
            while !Task.isCancelled {
                // No strong hold during the wait: the light never keeps a closed scanner alive.
                guard self != nil else { return }
                self?.tick()
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    /// The camera stops (a barcode was read, a photo is analysed, the screen closes): the light goes out.
    func stop() {
        watch?.cancel()
        watch = nil
        meter.reset()
        liveness.reset()
        litByItself = false
        if let device = sessionDevice ?? Self.backCamera(), device.hasTorch { set(false, on: device) }
        sessionDevice = nil
        scanner = nil
        if isLit { isLit = false }
    }

    /// The button: automatic, on, off. Applied at once, and kept for the next scans.
    func cycle() {
        mode = mode.next
        mode.save(in: defaults)
        meter.reset()
        litByItself = false
        guard let device = camera() else { return }
        set(mode == .on, on: device)
    }

    // MARK: Watching

    private func tick() {
        guard let device = camera() else { return }
        switch mode {
        case .on:
            // Put back when iOS turned it off (the camera restarted, the app came back to the foreground).
            set(true, on: device)
        case .off:
            set(false, on: device)
        case .auto:
            if litByItself {
                if device.torchMode == .on { return }
                // iOS turned it off: the scene is measured again before it comes back.
                litByItself = false
                meter.reset()
                if isLit { isLit = false }
            }
            let iso = device.iso
            let offset = device.exposureTargetOffset
            // Not the scanner's own camera for sure: its readings count only once they have moved.
            let trusted = liveness.feed(iso: iso, offset: offset) || sessionDevice != nil
            let dark = trusted ? ScanLight.isDark(iso: iso, seconds: device.exposureDuration.seconds,
                                                  aperture: device.lensAperture, offset: offset) : nil
            if meter.feed(dark) {
                litByItself = true
                set(true, on: device)
            }
        }
    }

    // MARK: The camera

    /// The camera the scanner runs, once its preview is on screen; until then (or if it can't be found) the back camera.
    private func camera() -> AVCaptureDevice? {
        if let sessionDevice { return sessionDevice }
        if let found = Self.runningCamera(in: scanner?.viewIfLoaded), found.hasTorch {
            sessionDevice = found
            return found
        }
        guard let back = Self.backCamera(), back.hasTorch else { return nil }
        return back
    }

    private static func backCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// The video camera of the capture session shown by a preview layer somewhere under this view.
    private static func runningCamera(in view: UIView?) -> AVCaptureDevice? {
        guard let view, let session = previewLayer(in: view.layer, depth: 0)?.session else { return nil }
        return session.inputs.compactMap { ($0 as? AVCaptureDeviceInput)?.device }.first { $0.hasMediaType(.video) }
    }

    private static func previewLayer(in layer: CALayer, depth: Int) -> AVCaptureVideoPreviewLayer? {
        if let preview = layer as? AVCaptureVideoPreviewLayer { return preview }
        guard depth < 12 else { return nil }
        for sublayer in layer.sublayers ?? [] {
            if let found = previewLayer(in: sublayer, depth: depth + 1) { return found }
        }
        return nil
    }

    /// Turns the light on or off when it isn't already so, then says what the light really is.
    private func set(_ lit: Bool, on device: AVCaptureDevice) {
        let wanted: AVCaptureDevice.TorchMode = lit ? .on : .off
        if device.torchMode != wanted, device.isTorchModeSupported(wanted), !lit || device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if lit {
                    try device.setTorchModeOn(level: Self.level)
                } else {
                    device.torchMode = .off
                }
            } catch {
                // The camera is busy or the light is not available right now: the next reading tries again.
            }
        }
        let now = device.torchMode == .on
        if isLit != now { isLit = now }
    }
}

/// The round button of the scanner's light, beside the shutter: a bolt, with an « A » in automatic mode, struck
/// through when it is off, yellow while the light is on.
struct ScanFlashButton: View {
    let torch: ScanTorch
    /// Called after the choice changed (the screen says the new choice for a moment).
    var onChange: () -> Void = {}

    var body: some View {
        Button {
            Haptics.tap()
            torch.cycle()
            onChange()
        } label: {
            Image(systemName: torch.mode == .off ? "bolt.slash.fill" : "bolt.fill")
                .font(.title3)
                .foregroundStyle(torch.isLit ? Color.yellow : Color.primary)
                .frame(width: 52, height: 52)
                .overlay(alignment: .bottomTrailing) {
                    if torch.mode == .auto {
                        Text(verbatim: "A")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .padding(.trailing, 11)
                            .padding(.bottom, 10)
                    }
                }
                .background(.regularMaterial, in: Circle())
        }
        .accessibilityLabel(tr("Flash"))
        .accessibilityValue(torch.mode.title)
        .accessibilityHint(tr("Change le mode du flash : automatique, activé ou désactivé"))
        .accessibilityIdentifier("scan-flash")
    }
}
