import XCTest
@testable import Ardane

/// Géométrie du scanner sans capteur de profondeur (Shared/Domains/Scanner/ScannerGeometry.swift) : ellipse d'une
/// assiette, échelle, redressement par homographie de rotation, aire d'un masque, propagation de l'erreur de
/// diamètre. Données SYNTHÉTIQUES : une assiette de 24 cm posée sur une table, vue par une caméra de focale
/// 500 px à 40 cm au-dessus de la table, droite ou inclinée ; les réponses attendues sont calculées à la main
/// (aire = π r², une assiette de 24 cm à 40 cm fait 24 × 500 / 40 = 300 px de diamètre une fois redressée).
final class ScannerGeometryTests: XCTestCase {
    private let focal = 500.0
    private let width = 640
    private let height = 480
    private var camera: CameraIntrinsics { CameraIntrinsics(fx: focal, fy: focal, cx: 320, cy: 240) }

    /// La gravité dans le repère de la caméra pour une caméra inclinée de `tilt` degrés par rapport à la verticale.
    private func gravity(tilt: Double) -> ScanVector3 {
        let angle = tilt * Double.pi / 180
        return ScanVector3(x: 0, y: sin(angle), z: cos(angle))
    }

    /// Le masque d'un disque posé sur la table, vu par la caméra : on lance le rayon de chaque pixel, on le coupe
    /// avec le plan de la table (à `distance` cm de la caméra, mesurés le long de la gravité) et on garde le pixel
    /// si le point touché est à moins de `radius` cm du centre du disque. Le centre est sur l'axe optique,
    /// décalé de `offset` cm horizontalement.
    private func discMask(tilt: Double, offset: Double, radius: Double, distance: Double = 40) -> FoodMask {
        let g = gravity(tilt: tilt)
        let center = ScanVector3(x: offset, y: 0, z: distance / g.z)
        let focalLength = focal
        return FoodMask(width: width, height: height) { (column: Int, row: Int) -> Bool in
            let px: Double = (Double(column) + 0.5 - 320) / focalLength
            let py: Double = (Double(row) + 0.5 - 240) / focalLength
            let ray = ScanVector3(x: px, y: py, z: 1)
            let along: Double = ray.dot(g)
            guard along > 1e-9 else { return false }
            let scale: Double = distance / along
            let dx: Double = ray.x * scale - center.x
            let dy: Double = ray.y * scale - center.y
            let dz: Double = ray.z * scale - center.z
            let squared: Double = dx * dx + dy * dy + dz * dz
            return squared <= radius * radius
        }
    }

    // MARK: Ellipse

    func testEllipseFitFindsCenterAxesAndAngle() throws {
        let a = 90.0
        let b = 50.0
        let angle = 30.0 * Double.pi / 180
        let cosine = cos(angle)
        let sine = sin(angle)
        let mask = FoodMask(width: 400, height: 300) { (column: Int, row: Int) -> Bool in
            let x: Double = Double(column) + 0.5 - 200
            let y: Double = Double(row) + 0.5 - 150
            let u: Double = (x * cosine + y * sine) / a
            let v: Double = (y * cosine - x * sine) / b
            let r: Double = u * u + v * v
            return r <= 1
        }
        let fit = try XCTUnwrap(ScanGeometry.fitEllipse(of: mask))
        XCTAssertEqual(fit.centerX, 200, accuracy: 0.5)
        XCTAssertEqual(fit.centerY, 150, accuracy: 0.5)
        XCTAssertEqual(fit.semiMajor, a, accuracy: 1.0)
        XCTAssertEqual(fit.semiMinor, b, accuracy: 1.0)
        XCTAssertEqual(fit.angle * 180 / Double.pi, 30, accuracy: 1.5)
        XCTAssertEqual(fit.majorDiameter, 180, accuracy: 2.0)
        XCTAssertEqual(fit.equivalentDiameter, 2 * (a * b).squareRoot(), accuracy: 1.5)
    }

    func testEllipseFitRefusesATinyMask() {
        let tiny = FoodMask(width: 10, height: 10) { column, row in column < 3 && row < 3 }
        XCTAssertNil(ScanGeometry.fitEllipse(of: tiny), "9 cellules : pas assez pour une ellipse")
        XCTAssertNil(ScanGeometry.fitEllipse(of: FoodMask(width: 10, height: 10)))
    }

    // MARK: Échelle et aire

    func testScaleFromAPlateOf24CmSeenOver300Pixels() throws {
        let scale = try XCTUnwrap(ScanGeometry.scale(
            referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 24), focalLengthPixels: 500
        ))
        XCTAssertEqual(scale.cmPerPixel, 0.08, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(scale.distanceCm), 40, accuracy: 1e-9, "distance = f · D / D_px = 500 × 24 / 300")
        XCTAssertEqual(scale.relativeError, ScaleReference.chosenPlateRelativeError)
        XCTAssertEqual(scale.source, .plateReference)

        let withoutFocal = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 24)))
        XCTAssertNil(withoutFocal.distanceCm, "sans focale, pas de distance (l'échelle reste connue)")
        XCTAssertEqual(withoutFocal.cmPerPixel, 0.08, accuracy: 1e-12)

        let registered = try XCTUnwrap(ScanGeometry.scale(
            referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 24, registered: true)
        ))
        XCTAssertEqual(registered.relativeError, ScaleReference.registeredPlateRelativeError)
        let card = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: 214, reference: ScaleReference.bankCard()))
        XCTAssertEqual(card.cmPerPixel, 8.56 / 214, accuracy: 1e-12)
        XCTAssertEqual(card.source, .referenceObject)
    }

    func testScaleRefusesWhatIsNotAPositiveDiameter() {
        let plate = ScaleReference.plate(diameterCm: 24)
        XCTAssertNil(ScanGeometry.scale(referenceDiameterPixels: 0, reference: plate))
        XCTAssertNil(ScanGeometry.scale(referenceDiameterPixels: -5, reference: plate))
        XCTAssertNil(ScanGeometry.scale(referenceDiameterPixels: Double.nan, reference: plate))
        XCTAssertNil(ScanGeometry.scale(referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 0)))
    }

    // MARK: Assiette coupée par le bord de la photo

    func testAPlateTouchingTheEdgeOfTheImageIsFlagged() {
        func disc(centerX: Double, centerY: Double, radius: Double) -> FoodMask {
            FoodMask(width: 100, height: 100) { column, row in
                let x = Double(column) + 0.5 - centerX
                let y = Double(row) + 0.5 - centerY
                return x * x + y * y <= radius * radius
            }
        }
        XCTAssertFalse(ScanGeometry.touchesImageBorder(disc(centerX: 50, centerY: 50, radius: 30)), "assiette entière, au milieu")
        XCTAssertTrue(ScanGeometry.touchesImageBorder(disc(centerX: 20, centerY: 50, radius: 30)), "coupée à gauche")
        XCTAssertTrue(ScanGeometry.touchesImageBorder(disc(centerX: 80, centerY: 50, radius: 30)), "coupée à droite")
        XCTAssertTrue(ScanGeometry.touchesImageBorder(disc(centerX: 50, centerY: 20, radius: 30)), "coupée en haut")
        XCTAssertTrue(ScanGeometry.touchesImageBorder(disc(centerX: 50, centerY: 70, radius: 30)), "coupée en bas")
        XCTAssertFalse(ScanGeometry.touchesImageBorder(FoodMask(width: 100, height: 100)), "un masque vide ne touche rien")

        // Le disque de rayon 48 couvre les colonnes 2 à 97 : il touche la marge de 3 cellules, pas celle de 1 ou 2.
        let wide = disc(centerX: 50, centerY: 50, radius: 48)
        XCTAssertFalse(ScanGeometry.touchesImageBorder(wide))
        XCTAssertFalse(ScanGeometry.touchesImageBorder(wide, marginCells: 2))
        XCTAssertTrue(ScanGeometry.touchesImageBorder(wide, marginCells: 3))
        XCTAssertFalse(ScanGeometry.touchesImageBorder(wide, marginCells: 0), "une marge de 0 est lue comme 1")
    }

    func testACutPlateGivesAScaleThatIsTooLarge() throws {
        // La même assiette de 24 cm (12,5 px/cm, 300 px) : entière à 10 cm du centre de l'image, coupée par le bord
        // droit à 20 cm. Coupée, son diamètre de même aire est trop petit : l'échelle (cm par pixel) est trop
        // grande, et toutes les aires avec elle. Le signal du bord dit de ne pas s'y fier.
        let whole = discMask(tilt: 0, offset: 10, radius: 12)
        let cut = discMask(tilt: 0, offset: 20, radius: 12)
        XCTAssertFalse(ScanGeometry.touchesImageBorder(whole))
        XCTAssertTrue(ScanGeometry.touchesImageBorder(cut))

        let wholeDiameter = try XCTUnwrap(ScanGeometry.plateDiameterPixels(of: whole, rectification: .identity))
        let cutDiameter = try XCTUnwrap(ScanGeometry.plateDiameterPixels(of: cut, rectification: .identity))
        XCTAssertEqual(wholeDiameter, 300, accuracy: 3)
        XCTAssertLessThan(cutDiameter, 0.92 * 300, "plus de 8 % trop petit : l'échelle serait fausse de plus de 8 %")
    }

    func testAreaOfAMaskIsPixelsTimesTheSquareOfTheScale() throws {
        // 10 000 pixels à 40 cm avec f = 500 px : (40 / 500)² = 0,0064 cm² par pixel → 64 cm².
        XCTAssertEqual(try XCTUnwrap(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: 40, focalLengthPixels: 500)), 64, accuracy: 1e-9)
        // Une focale inconnue (0), négative ou non finie, comme une distance ou un nombre de pixels qui n'en sont pas :
        // pas d'aire (jamais une aire infinie ou inventée).
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: 40, focalLengthPixels: 0))
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: 40, focalLengthPixels: -500))
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: 40, focalLengthPixels: Double.nan))
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: 40, focalLengthPixels: Double.infinity))
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: 0, focalLengthPixels: 500))
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 10_000, distanceCm: Double.nan, focalLengthPixels: 500))
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: 0, distanceCm: 40, focalLengthPixels: 500), "zéro pixel : aire inconnue, pas 0")
        XCTAssertNil(ScanGeometry.areaCm2(pixelCount: -3, distanceCm: 40, focalLengthPixels: 500))

        // Un disque de 50 px de rayon à 0,08 cm/px est un disque de 4 cm de rayon : π × 16 = 50,27 cm².
        let disc = FoodMask(width: 200, height: 200) { column, row in
            let x = Double(column) + 0.5 - 100
            let y = Double(row) + 0.5 - 100
            return x * x + y * y <= 2_500
        }
        let scale = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 24)))
        let area = try XCTUnwrap(ScanGeometry.areaEstimate(of: disc, scale: scale))
        XCTAssertEqual(area.median, Double.pi * 16, accuracy: 0.6)
        XCTAssertEqual(area.median, Double(disc.count) * 0.0064, accuracy: 1e-9)
        XCTAssertEqual(area.sources, [.plateReference])
        XCTAssertFalse(area.isPrior)
    }

    func testAreaSpreadCombinesTwiceTheDiameterErrorTheMeasureInPixelsAndTheMaskError() throws {
        let disc = FoodMask(width: 100, height: 100) { column, row in
            let x = Double(column) + 0.5 - 50
            let y = Double(row) + 0.5 - 50
            return x * x + y * y <= 900
        }
        let scale = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 24)))
        // Sans erreur de mesure en pixels : σ_D = √ln(1 + 0.08²) ; σ_A = 2 σ_D ; σ_mask = √ln(1 + 0.10²) ;
        // σ = √(σ_A² + σ_mask²) = 0,1883.
        let withoutPixels = try XCTUnwrap(ScanGeometry.areaEstimate(
            of: disc, scale: scale, maskRelativeError: 0.10, diameterPixelsRelativeError: 0
        ))
        let diameterSigma = ScanLogNormal.sigma(relativeError: 0.08)
        let expected = (pow(2 * diameterSigma, 2) + pow(ScanLogNormal.sigma(relativeError: 0.10), 2)).squareRoot()
        XCTAssertEqual(withoutPixels.sigmaLog, expected, accuracy: 1e-12)
        XCTAssertEqual(withoutPixels.sigmaLog, 0.1883, accuracy: 0.0005)

        // Avec 5 % d'erreur sur le diamètre mesuré en pixels : s'ajoute dans le logarithme, doublé comme l'autre.
        let fivePercent = try XCTUnwrap(ScanGeometry.areaEstimate(
            of: disc, scale: scale, maskRelativeError: 0.10, diameterPixelsRelativeError: 0.05
        ))
        let pixelSigma = ScanLogNormal.sigma(relativeError: 0.05)
        let expectedWithPixels = (pow(2 * diameterSigma, 2) + pow(2 * pixelSigma, 2) + pow(ScanLogNormal.sigma(relativeError: 0.10), 2)).squareRoot()
        XCTAssertEqual(fivePercent.sigmaLog, expectedWithPixels, accuracy: 1e-12)
        XCTAssertEqual(fivePercent.sigmaLog, 0.2132, accuracy: 0.0005)
        XCTAssertEqual(fivePercent.median, withoutPixels.median, accuracy: 1e-12, "l'erreur de mesure élargit l'écart, pas la médiane")

        // Par défaut : la valeur initiale (à mesurer), 2 %, est comptée.
        let byDefault = try XCTUnwrap(ScanGeometry.areaEstimate(of: disc, scale: scale, maskRelativeError: 0.10))
        XCTAssertEqual(ScanGeometry.defaultDiameterPixelsRelativeError, 0.02)
        XCTAssertEqual(byDefault.sigmaLog, 0.1925, accuracy: 0.0005)
        XCTAssertGreaterThan(byDefault.sigmaLog, withoutPixels.sigmaLog)

        let nothing = FoodMask(width: 10, height: 10)
        XCTAssertNil(ScanGeometry.areaEstimate(of: nothing, scale: scale), "un masque vide n'a pas une aire de 0 : elle est inconnue")
    }

    func testDiameterErrorOfTenPercentGivesAnAreaErrorOfTwentyOnePercent() throws {
        XCTAssertEqual(ScanGeometry.areaFactor(diameterRatio: 1.1), 1.21, accuracy: 1e-12)
        XCTAssertEqual(ScanGeometry.areaFactor(diameterRatio: 0.9), 0.81, accuracy: 1e-12)
        XCTAssertEqual(ScanGeometry.areaFactor(diameterRatio: 1), 1, accuracy: 1e-12)

        // Même masque, assiette annoncée de 24 cm ou de 26,4 cm (10 % de plus) : l'aire est 21 % plus grande.
        let disc = FoodMask(width: 100, height: 100) { column, row in
            let x = Double(column) + 0.5 - 50
            let y = Double(row) + 0.5 - 50
            return x * x + y * y <= 900
        }
        let exact = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 24)))
        let tooBig = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: 300, reference: ScaleReference.plate(diameterCm: 26.4)))
        let areaExact = try XCTUnwrap(ScanGeometry.areaEstimate(of: disc, scale: exact)).median
        let areaTooBig = try XCTUnwrap(ScanGeometry.areaEstimate(of: disc, scale: tooBig)).median
        XCTAssertEqual(areaTooBig / areaExact, 1.21, accuracy: 1e-9)

        // Dans le logarithme l'erreur double : σ(aire) = 2 σ(diamètre), et √ln(1 + 0,1²) = 0,09975.
        XCTAssertEqual(ScanLogNormal.sigma(relativeError: 0.10), 0.0997513, accuracy: 1e-6)
        XCTAssertEqual(ScanGeometry.areaSigma(diameterSigma: ScanLogNormal.sigma(relativeError: 0.10)), 0.1995027, accuracy: 1e-6)
    }

    // MARK: Redressement

    func testRectifyingRotationPutsGravityOnTheOpticalAxis() throws {
        let directions = [
            gravity(tilt: 0), gravity(tilt: 20), gravity(tilt: 45), gravity(tilt: 60),
            ScanVector3(x: 0.2, y: -0.3, z: 0.9),
        ]
        for direction in directions {
            let unit = try XCTUnwrap(direction.normalized)
            let rotation = try XCTUnwrap(ScanGeometry.rectifyingRotation(gravity: direction))
            let rotated = rotation.apply(unit)
            XCTAssertEqual(rotated.x, 0, accuracy: 1e-12)
            XCTAssertEqual(rotated.y, 0, accuracy: 1e-12)
            XCTAssertEqual(rotated.z, 1, accuracy: 1e-12)
            XCTAssertEqual(rotation.determinant, 1, accuracy: 1e-12, "une rotation conserve les longueurs et les aires")
        }
        // Une caméra déjà à la verticale : rien à redresser.
        let identity = try XCTUnwrap(ScanGeometry.rectifyingRotation(gravity: gravity(tilt: 0)))
        for (index, value) in ScanMatrix3.identity.values.enumerated() {
            XCTAssertEqual(identity.values[index], value, accuracy: 1e-12)
        }
    }

    func testTooMuchTiltOrACameraLookingUpIsRefused() throws {
        XCTAssertEqual(try XCTUnwrap(ScanGeometry.tiltDegrees(gravity: gravity(tilt: 30))), 30, accuracy: 1e-9)
        XCTAssertNotNil(ScanGeometry.rectifyingRotation(gravity: gravity(tilt: 60)))
        XCTAssertNil(ScanGeometry.rectifyingRotation(gravity: gravity(tilt: 70)), "au-delà de 65° : trop oblique")
        XCTAssertNotNil(ScanGeometry.rectifyingRotation(gravity: gravity(tilt: 70), maximumTiltDegrees: 80))
        XCTAssertNil(ScanGeometry.rectifyingRotation(gravity: ScanVector3(x: 0, y: 0, z: -1)), "caméra tournée vers le haut")
        XCTAssertNil(ScanGeometry.rectifyingRotation(gravity: ScanVector3(x: 0, y: 0, z: 0)))
        XCTAssertNil(ScanGeometry.rectifyingHomography(intrinsics: CameraIntrinsics(fx: 0, fy: 500, cx: 320, cy: 240), gravity: gravity(tilt: 10)))
    }

    func testHomographyOfATiltedPlateGivesTheAreaSeenFromAbove() throws {
        // π × 12² × (500 / 40)² = 70 685,8 pixels : l'assiette vue de dessus, à 12,5 px par cm.
        let expected = Double.pi * 144 * pow(focal / 40, 2)
        for tilt in [0.0, 30.0, 45.0] {
            let plate = discMask(tilt: tilt, offset: 0, radius: 12)
            let homography = try XCTUnwrap(ScanGeometry.rectifyingHomography(intrinsics: camera, gravity: gravity(tilt: tilt)))
            XCTAssertEqual(homography.determinant, 1, accuracy: 1e-9)
            let rectified = ScanGeometry.rectifiedPixelCount(of: plate, homography: homography)
            XCTAssertEqual(rectified, expected, accuracy: expected * 0.005, "inclinaison \(tilt)°")
            if tilt >= 30 {
                XCTAssertLessThan(Double(plate.count), expected * 0.8, "inclinée, l'assiette couvre moins de pixels (\(tilt)°)")
            }
        }
        // Une homographie identité ne change rien.
        let plate = discMask(tilt: 0, offset: 0, radius: 12)
        XCTAssertEqual(ScanGeometry.rectifiedPixelCount(of: plate, homography: .identity), Double(plate.count), accuracy: 1e-9)
    }

    func testPlateGivesTheScaleAndTheAreaOfAFoodOnATiltedTable() throws {
        // Un aliment rond de 5 cm de rayon posé à côté du centre de l'assiette : π × 25 = 78,54 cm².
        for tilt in [0.0, 30.0, 45.0] {
            let plate = discMask(tilt: tilt, offset: 0, radius: 12)
            let food = discMask(tilt: tilt, offset: 6, radius: 5)
            let homography = try XCTUnwrap(ScanGeometry.rectifyingHomography(intrinsics: camera, gravity: gravity(tilt: tilt)))
            let diameter = try XCTUnwrap(ScanGeometry.plateDiameterPixels(of: plate, rectification: homography))
            XCTAssertEqual(diameter, 300, accuracy: 3, "24 cm à 12,5 px/cm (\(tilt)°)")
            let scale = try XCTUnwrap(ScanGeometry.scale(
                referenceDiameterPixels: diameter, reference: ScaleReference.plate(diameterCm: 24), focalLengthPixels: focal
            ))
            XCTAssertEqual(scale.cmPerPixel, 0.08, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(scale.distanceCm), 40, accuracy: 0.5)
            let area = try XCTUnwrap(ScanGeometry.areaEstimate(of: food, scale: scale, rectification: homography))
            XCTAssertEqual(area.median, Double.pi * 25, accuracy: Double.pi * 25 * 0.015, "inclinaison \(tilt)°")
        }
    }

    func testWithoutRectificationATiltedPhotoUnderestimatesTheArea() throws {
        // Le même aliment à 45°, sans redressement : l'ellipse de l'assiette donne une échelle fausse et les
        // pixels de l'aliment sont écrasés. L'erreur dépasse 10 % : c'est ce que le redressement corrige.
        let plate = discMask(tilt: 45, offset: 0, radius: 12)
        let food = discMask(tilt: 45, offset: 6, radius: 5)
        let diameter = try XCTUnwrap(ScanGeometry.plateDiameterPixels(of: plate))
        let scale = try XCTUnwrap(ScanGeometry.scale(referenceDiameterPixels: diameter, reference: ScaleReference.plate(diameterCm: 24)))
        let area = try XCTUnwrap(ScanGeometry.areaEstimate(of: food, scale: scale)).median
        XCTAssertGreaterThan(abs(area - Double.pi * 25) / (Double.pi * 25), 0.10)
    }
}
