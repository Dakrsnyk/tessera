import Foundation

// The geometry of the route WITHOUT depth sensor (the universal one): a plate of known diameter gives the scale of
// the photo, a rotation by the gravity makes the table face the camera, the mask of a food gives its area in cm².
// Lengths in cm, areas in cm², angles in radians unless a name says degrees. Every function is pure.

/// A vector of three numbers (a direction in the frame of the camera: x to the right, y down, z along the optical axis).
struct ScanVector3: Hashable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    var length: Double { (x * x + y * y + z * z).squareRoot() }

    /// The vector of length 1 with the same direction, nil for a vector that is null or not finite.
    var normalized: ScanVector3? {
        let l = length
        guard l.isFinite, l > 1e-12 else { return nil }
        return ScanVector3(x: x / l, y: y / l, z: z / l)
    }

    func dot(_ other: ScanVector3) -> Double { x * other.x + y * other.y + z * other.z }

    func cross(_ other: ScanVector3) -> ScanVector3 {
        ScanVector3(x: y * other.z - z * other.y, y: z * other.x - x * other.z, z: x * other.y - y * other.x)
    }
}

/// A 3×3 matrix of Doubles, row by row: enough for a camera matrix, a rotation and a homography.
struct ScanMatrix3: Hashable, Sendable {
    let values: [Double]

    /// Nine numbers, row by row. Anything else gives the identity.
    init(_ values: [Double]) {
        self.values = values.count == 9 ? values : [1, 0, 0, 0, 1, 0, 0, 0, 1]
    }

    static let identity = ScanMatrix3([1, 0, 0, 0, 1, 0, 0, 0, 1])

    subscript(row: Int, column: Int) -> Double { values[row * 3 + column] }

    static func * (lhs: ScanMatrix3, rhs: ScanMatrix3) -> ScanMatrix3 {
        var result = [Double](repeating: 0, count: 9)
        for row in 0..<3 {
            for column in 0..<3 {
                var sum = 0.0
                for k in 0..<3 { sum += lhs[row, k] * rhs[k, column] }
                result[row * 3 + column] = sum
            }
        }
        return ScanMatrix3(result)
    }

    static func + (lhs: ScanMatrix3, rhs: ScanMatrix3) -> ScanMatrix3 {
        ScanMatrix3(zip(lhs.values, rhs.values).map { $0 + $1 })
    }

    func scaled(by factor: Double) -> ScanMatrix3 {
        ScanMatrix3(values.map { $0 * factor })
    }

    var determinant: Double {
        let a = self[0, 0], b = self[0, 1], c = self[0, 2]
        let d = self[1, 0], e = self[1, 1], f = self[1, 2]
        let g = self[2, 0], h = self[2, 1], i = self[2, 2]
        return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    }

    /// The inverse, nil when the matrix cannot be inverted.
    var inverse: ScanMatrix3? {
        let det = determinant
        guard det.isFinite, abs(det) > 1e-12 else { return nil }
        let a = self[0, 0], b = self[0, 1], c = self[0, 2]
        let d = self[1, 0], e = self[1, 1], f = self[1, 2]
        let g = self[2, 0], h = self[2, 1], i = self[2, 2]
        let cofactors: [Double] = [
            e * i - f * h, c * h - b * i, b * f - c * e,
            f * g - d * i, a * i - c * g, c * d - a * f,
            d * h - e * g, b * g - a * h, a * e - b * d,
        ]
        return ScanMatrix3(cofactors.map { $0 / det })
    }

    /// The matrix applied to the point (x, y, 1): the homogeneous result (x', y', w'). The point on the image is
    /// (x' / w', y' / w').
    func apply(x: Double, y: Double) -> (x: Double, y: Double, w: Double) {
        (
            self[0, 0] * x + self[0, 1] * y + self[0, 2],
            self[1, 0] * x + self[1, 1] * y + self[1, 2],
            self[2, 0] * x + self[2, 1] * y + self[2, 2]
        )
    }

    /// The matrix applied to a vector.
    func apply(_ v: ScanVector3) -> ScanVector3 {
        ScanVector3(
            x: self[0, 0] * v.x + self[0, 1] * v.y + self[0, 2] * v.z,
            y: self[1, 0] * v.x + self[1, 1] * v.y + self[1, 2] * v.z,
            z: self[2, 0] * v.x + self[2, 1] * v.y + self[2, 2] * v.z
        )
    }
}

/// The pinhole camera, in pixels: the focal lengths and the optical center. To be expressed on the grid of the
/// mask it is used with (`scaled(by:)` when the mask is smaller than the photo).
struct CameraIntrinsics: Hashable, Sendable {
    var fx: Double
    var fy: Double
    var cx: Double
    var cy: Double

    /// The focal length used for a distance, the mean of the two.
    var focalLength: Double { (fx + fy) / 2 }

    var isValid: Bool {
        [fx, fy, cx, cy].allSatisfy { $0.isFinite } && fx > 0 && fy > 0
    }

    var matrix: ScanMatrix3 {
        ScanMatrix3([fx, 0, cx, 0, fy, cy, 0, 0, 1])
    }

    /// The camera for an image `factor` times larger or smaller (a depth map is smaller than the photo).
    func scaled(by factor: Double) -> CameraIntrinsics {
        CameraIntrinsics(fx: fx * factor, fy: fy * factor, cx: cx * factor, cy: cy * factor)
    }
}

/// An object of known size that gives the scale of the photo: the diameter of a plate, the length of a card.
struct ScaleReference: Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case plate
        case referenceObject
    }

    var kind: Kind
    /// The real diameter (plate) or length (object), in cm.
    var diameterCm: Double
    /// How far off the diameter can be, as a share of its value (a coefficient of variation, 1 σ).
    var relativeError: Double

    /// À MESURER: the person picks a usual size (20, 24 or 27 cm) but their plate is never exactly that. 8 % is a
    /// guess, to replace by what the weighed meals show.
    static let chosenPlateRelativeError = 0.08
    /// À MESURER: a plate whose diameter the person measured once and saved.
    static let registeredPlateRelativeError = 0.02
    /// À MESURER: an object of a standard size (bank card, coin), measured on the photo.
    static let standardObjectRelativeError = 0.01
    /// The long side of a bank card, ISO/IEC 7810 ID-1 (85.60 mm).
    static let bankCardLengthCm = 8.56

    static func plate(diameterCm: Double, registered: Bool = false) -> ScaleReference {
        ScaleReference(
            kind: .plate, diameterCm: diameterCm,
            relativeError: registered ? registeredPlateRelativeError : chosenPlateRelativeError
        )
    }

    static func bankCard() -> ScaleReference {
        ScaleReference(kind: .referenceObject, diameterCm: bankCardLengthCm, relativeError: standardObjectRelativeError)
    }

    var source: EstimateSource {
        kind == .plate ? .plateReference : .referenceObject
    }
}

/// The scale of a photo at the level of the table: how many cm one pixel covers there.
struct ImageScale: Hashable, Sendable {
    var cmPerPixel: Double
    /// The distance from the camera to the table, along the optical axis of the (rectified) camera: f · D / D_px.
    /// Nil when the focal length is not known.
    var distanceCm: Double?
    /// The relative error of the scale, that of the reference diameter.
    var relativeError: Double
    var source: EstimateSource
}

/// An ellipse fitted on a mask (a plate seen from the side is an ellipse).
struct EllipseFit: Hashable, Sendable {
    var centerX: Double
    var centerY: Double
    var semiMajor: Double
    var semiMinor: Double
    /// The angle of the major axis with the x axis, in radians, between −π/2 and π/2 (y points down).
    var angle: Double

    var majorDiameter: Double { 2 * semiMajor }
    var minorDiameter: Double { 2 * semiMinor }
    /// The diameter of the circle that has the same area.
    var equivalentDiameter: Double { 2 * (semiMajor * semiMinor).squareRoot() }
}

enum ScanGeometry {
    // MARK: Constants

    /// Beyond this tilt of the camera (the angle between its optical axis and the vertical) the table is seen too
    /// obliquely: a food that has some height hides a part of itself and the plane assumption gives errors.
    /// À MESURER: 65° is a guess.
    static let defaultMaximumTiltDegrees = 65.0
    /// À MESURER: the share of the area of a food that the mask may get wrong (the quality of the segmentation).
    static let defaultMaskRelativeError = 0.10
    /// À MESURER: the error of the measure of the diameter of the reference IN PIXELS, as a share of that diameter
    /// (a coefficient of variation, 1 σ). The edge of the mask of the plate is a few pixels off, so is the circle
    /// fitted on it: 2 % is 6 px on 300 px, a guess to replace by the comparison with plates measured by hand. It
    /// comes on top of the error of the real diameter (`ScaleReference.relativeError`): the scale is D / D_px.
    static let defaultDiameterPixelsRelativeError = 0.02
    /// A mask smaller than this many cells is not fitted: too few points for an ellipse.
    static let minimumMaskCells = 50
    /// A mask with a cell in this many outermost rows or columns of its grid touches the edge of the image.
    static let defaultBorderMarginCells = 1

    // MARK: Ellipse of the plate

    /// The ellipse that has the same center and the same second moments as the mask (a filled ellipse has its
    /// semi-axes at twice the standard deviation along its axes). Nil for a mask that is too small or flat.
    static func fitEllipse(of mask: FoodMask) -> EllipseFit? {
        var n = 0.0
        var sumX = 0.0
        var sumY = 0.0
        var sumXX = 0.0
        var sumYY = 0.0
        var sumXY = 0.0
        mask.forEachCell { column, row in
            let px = Double(column) + 0.5
            let py = Double(row) + 0.5
            n += 1
            sumX += px
            sumY += py
            sumXX += px * px
            sumYY += py * py
            sumXY += px * py
        }
        guard n >= Double(minimumMaskCells) else { return nil }
        let meanX = sumX / n
        let meanY = sumY / n
        let varX = sumXX / n - meanX * meanX
        let varY = sumYY / n - meanY * meanY
        let covXY = sumXY / n - meanX * meanY
        let halfTrace = (varX + varY) / 2
        let discriminant = max(0, halfTrace * halfTrace - (varX * varY - covXY * covXY)).squareRoot()
        let largest = halfTrace + discriminant
        let smallest = max(0, halfTrace - discriminant)
        guard largest > 0, smallest > 0 else { return nil }
        return EllipseFit(
            centerX: meanX, centerY: meanY, semiMajor: 2 * largest.squareRoot(), semiMinor: 2 * smallest.squareRoot(),
            angle: 0.5 * atan2(2 * covXY, varX - varY)
        )
    }

    // MARK: Rectification

    /// The angle in degrees between the optical axis and the vertical, for a gravity direction expressed in the
    /// frame of the camera (x right, y down, z forward, gravity pointing to the ground). 0 when the camera looks
    /// straight down at the table. Nil for a null or not finite direction.
    static func tiltDegrees(gravity: ScanVector3) -> Double? {
        guard let g = gravity.normalized else { return nil }
        return acos(max(-1, min(1, g.z))) * 180 / Double.pi
    }

    /// The smallest rotation R of the camera frame that puts gravity on the optical axis (R · g = (0, 0, 1)): the
    /// camera as if it looked straight down. Nil when the camera looks up, or is tilted more than
    /// `maximumTiltDegrees`.
    static func rectifyingRotation(
        gravity: ScanVector3, maximumTiltDegrees: Double = ScanGeometry.defaultMaximumTiltDegrees
    ) -> ScanMatrix3? {
        guard let g = gravity.normalized, g.z > 0,
              let tilt = tiltDegrees(gravity: g), tilt <= maximumTiltDegrees else { return nil }
        // Rodrigues for two unit vectors a → b: R = I + [v]× + [v]×² / (1 + a·b), with v = a × b.
        let v = g.cross(ScanVector3(x: 0, y: 0, z: 1))
        let skew = ScanMatrix3([0, -v.z, v.y, v.z, 0, -v.x, -v.y, v.x, 0])
        return ScanMatrix3.identity + skew + (skew * skew).scaled(by: 1 / (1 + g.z))
    }

    /// The homography H = K R K⁻¹ that turns the photo into the photo of the same table taken from straight
    /// above, by the same camera. Valid for every point of the table plane (and for it only).
    static func rectifyingHomography(
        intrinsics: CameraIntrinsics, gravity: ScanVector3,
        maximumTiltDegrees: Double = ScanGeometry.defaultMaximumTiltDegrees
    ) -> ScanMatrix3? {
        guard intrinsics.isValid, let rotation = rectifyingRotation(gravity: gravity, maximumTiltDegrees: maximumTiltDegrees),
              let inverse = intrinsics.matrix.inverse else { return nil }
        return intrinsics.matrix * rotation * inverse
    }

    /// The number of pixels the mask would cover on the rectified photo: the sum over its cells of the local area
    /// factor det(H) / w³ of the homography. No image is resampled, a mask on a small grid costs little.
    static func rectifiedPixelCount(of mask: FoodMask, homography: ScanMatrix3) -> Double {
        let determinant = homography.determinant
        guard determinant.isFinite else { return 0 }
        var total = 0.0
        mask.forEachCell { column, row in
            let w = homography.apply(x: Double(column) + 0.5, y: Double(row) + 0.5).w
            if w > 1e-9 { total += determinant / (w * w * w) }
        }
        return total
    }

    // MARK: Scale

    /// True when a cell of the mask is in the outermost `marginCells` rows or columns of its grid: the plate is cut
    /// by the edge of the photo. Its diameter in pixels is then too small (the equal-area circle) or wrong (an
    /// ellipse fitted on a cap), so the scale is NOT reliable: the app asks for another photo, or refuses the
    /// plate as a reference. False for an empty mask (nothing is cut). `marginCells` is at least 1.
    static func touchesImageBorder(_ mask: FoodMask, marginCells: Int = ScanGeometry.defaultBorderMarginCells) -> Bool {
        let margin = max(1, marginCells)
        var touches = false
        mask.forEachCell { column, row in
            if column < margin || row < margin || column >= mask.width - margin || row >= mask.height - margin {
                touches = true
            }
        }
        return touches
    }

    /// The diameter of a plate in pixels, from the mask of the whole plate (food included): on the rectified photo
    /// when a homography is given (the plate is then a circle: the diameter of the circle of the same area),
    /// otherwise the major axis of the fitted ellipse (right for a camera that looks nearly straight down).
    static func plateDiameterPixels(of plate: FoodMask, rectification: ScanMatrix3? = nil) -> Double? {
        if let rectification {
            let area = rectifiedPixelCount(of: plate, homography: rectification)
            guard area >= Double(minimumMaskCells) else { return nil }
            return 2 * (area / Double.pi).squareRoot()
        }
        return fitEllipse(of: plate)?.majorDiameter
    }

    /// The scale given by a reference seen over `referenceDiameterPixels` pixels: D / D_px cm per pixel, which is
    /// distance / f for a camera at the distance f · D / D_px. Nil for a diameter that is not a positive number.
    static func scale(
        referenceDiameterPixels: Double, reference: ScaleReference, focalLengthPixels: Double? = nil
    ) -> ImageScale? {
        guard referenceDiameterPixels.isFinite, referenceDiameterPixels > 0,
              reference.diameterCm.isFinite, reference.diameterCm > 0 else { return nil }
        let cmPerPixel = reference.diameterCm / referenceDiameterPixels
        var distance: Double?
        if let focal = focalLengthPixels, focal.isFinite, focal > 0 { distance = focal * cmPerPixel }
        return ImageScale(cmPerPixel: cmPerPixel, distanceCm: distance, relativeError: reference.relativeError, source: reference.source)
    }

    // MARK: Area

    /// The area in cm² of `pixelCount` pixels at a distance: A = N_px · (distance / f)². Nil unless the three
    /// numbers are finite and positive: a focal length of 0 (unknown camera) or not finite would give an infinite
    /// or invented area, and an unknown area is never 0.
    static func areaCm2(pixelCount: Double, distanceCm: Double, focalLengthPixels: Double) -> Double? {
        guard pixelCount.isFinite, pixelCount > 0, distanceCm.isFinite, distanceCm > 0,
              focalLengthPixels.isFinite, focalLengthPixels > 0 else { return nil }
        let side = distanceCm / focalLengthPixels
        return pixelCount * side * side
    }

    /// The area of a food in cm², as an estimate with its error: the mask (rectified when a homography is given)
    /// times the square of the scale. The error is that of the area (twice that of the diameter) for the real
    /// diameter of the reference AND for its measure in pixels (the scale is D / D_px: two independent errors,
    /// added in the logarithm), combined with the error of the mask itself.
    static func areaEstimate(
        of mask: FoodMask, scale: ImageScale, rectification: ScanMatrix3? = nil,
        maskRelativeError: Double = ScanGeometry.defaultMaskRelativeError,
        diameterPixelsRelativeError: Double = ScanGeometry.defaultDiameterPixelsRelativeError
    ) -> ScanEstimate? {
        let pixels = rectification.map { rectifiedPixelCount(of: mask, homography: $0) } ?? Double(mask.count)
        guard pixels > 0, scale.cmPerPixel.isFinite, scale.cmPerPixel > 0 else { return nil }
        let area = pixels * scale.cmPerPixel * scale.cmPerPixel
        let sigma = ScanLogNormal.combined([
            areaSigma(diameterSigma: ScanLogNormal.sigma(relativeError: scale.relativeError)),
            areaSigma(diameterSigma: ScanLogNormal.sigma(relativeError: diameterPixelsRelativeError)),
            ScanLogNormal.sigma(relativeError: maskRelativeError),
        ])
        return ScanEstimate(median: area, sigmaLog: sigma, sources: [scale.source])
    }

    // MARK: Error propagation

    /// The factor on the area when the diameter of the reference is `diameterRatio` times the real one: the scale
    /// is D / D_px, the area goes with the square of it. A diameter 10 % too large (1.1) gives an area 21 % too large.
    static func areaFactor(diameterRatio: Double) -> Double {
        diameterRatio * diameterRatio
    }

    /// The σ of ln(area) for the σ of ln(diameter): doubled (the relative error of the area is twice that of the
    /// diameter), and the volume would triple it.
    static func areaSigma(diameterSigma: Double) -> Double {
        2 * diameterSigma
    }
}
