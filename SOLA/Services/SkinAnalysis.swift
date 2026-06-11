import Foundation
import CoreGraphics
import UIKit
import Vision

// Métriques réelles dérivées d'une photo (analyse colorimétrique on-device).
struct SkinFaceBox: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct SkinFaceMeshData {
    var faceBox: SkinFaceBox
    var points: [CGPoint]
}

struct SkinMetrics: Codable, Equatable {
    var tan: Int        // teinte 0…100
    var glow: Int       // éclat / luminosité 0…100
    var evenness: Int   // uniformité 0…100
    var redness: Int    // rougeur 0…100
    var faceBox: SkinFaceBox? = nil
    var sampleCount: Int? = nil
    var advice: String? = nil   // conseil texte généré on-device (SkinAdvice)

    /// Palier 1–5 aligné sur la définition canonique de l'indice (seuils 35/55/75/90).
    var tanLevel: Int {
        switch tan {
        case ..<35: return 1
        case ..<55: return 2
        case ..<75: return 3
        case ..<90: return 4
        default:    return 5
        }
    }
    var hueLabel: String { solaHueLabel(tan) }
}

// Analyse colorimétrique de la peau à partir des pixels de l'image.
enum SkinAnalysis {
    static func analyze(_ image: UIImage) -> SkinMetrics? {
        let prepared = image.solaAnalysisImage(maxDimension: 1200)
        guard let cg = prepared.cgImage else { return nil }

        let detection = detectFace(in: cg)
        let faceBox = detection?.box
        let side = 120
        var px = [UInt8](repeating: 0, count: side * side * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Calibration lumière : balance des blancs ancrée sur le blanc de l'œil
        // (référence neutre présente sur tout selfie), repli gray-world sinon.
        // Sans ça, la teinte mesurée dépend de l'éclairage et n'est pas reproductible.
        let gains = whiteBalanceGains(px, side: side, eyeRegions: detection?.eyeRegions ?? [])

        let regions = sampleRegions(faceBox: faceBox)
        let strict = collectPixels(px, side: side, regions: regions, gains: gains, strictSkinFilter: true)
        let relaxed = strict.count >= 80 ? strict : collectPixels(px, side: side, regions: regions, gains: gains, strictSkinFilter: false)
        guard let stats = PixelStats(samples: relaxed), stats.count >= 30 else { return nil }

        func clamp(_ v: Double) -> Int { Int(min(100, max(0, v)).rounded()) }

        // Teinte : plus la zone peau est foncée et chaude, plus la teinte est élevée.
        let tan = clamp(31 + (0.74 - stats.luma) * 122 + stats.warmth * 72)
        // Éclat : lumière de peau + faible dispersion, sans récompenser les reflets.
        let glow = clamp(30 + stats.luma * 72 - stats.lumaStd * 115 - stats.redness * 20)
        // Uniformité : stabilité de luminance et de dominante rouge sur les zones peau.
        let evenness = clamp(100 - stats.lumaStd * 430 - stats.redStd * 180)
        // Rougeur : excès relatif du rouge, atténué pour les carnations naturellement chaudes.
        let redness = clamp(stats.redness * 330 + max(0, stats.meanR - stats.meanG) * 72 - stats.warmth * 22)

        return SkinMetrics(tan: tan, glow: glow, evenness: evenness, redness: redness,
                           faceBox: faceBox, sampleCount: stats.count)
    }

    /// Détection de visage réutilisable (sert à ancrer les annotations sur la photo).
    static func faceBox(in image: UIImage) -> SkinFaceBox? {
        guard let cg = image.solaAnalysisImage(maxDimension: 1200).cgImage else { return nil }
        return detectFace(in: cg)?.box
    }

    static func faceMesh(in image: UIImage) -> SkinFaceMeshData? {
        guard let cg = image.solaAnalysisImage(maxDimension: 1200).cgImage else { return nil }
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }),
              let landmarks = face.landmarks else { return nil }

        let bb = face.boundingBox
        var points: [CGPoint] = []
        [
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.leftEyebrow,
            landmarks.rightEyebrow,
            landmarks.nose,
            landmarks.noseCrest,
            landmarks.medianLine,
            landmarks.outerLips,
            landmarks.innerLips,
            landmarks.leftPupil,
            landmarks.rightPupil
        ].compactMap { $0 }.forEach { points.append(contentsOf: normalizedImagePoints(from: $0, faceBox: bb)) }

        if let contour = landmarks.faceContour {
            let topY = 1 - bb.maxY
            let bottomLimit = topY + bb.height * 0.90
            points.append(contentsOf: normalizedImagePoints(from: contour, faceBox: bb).filter { $0.y <= bottomLimit })
        }

        points = deduplicated(points.filter { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
        guard points.count >= 12 else { return nil }

        let box = SkinFaceBox(x: bb.origin.x, y: bb.origin.y, width: bb.width, height: bb.height)
        return SkinFaceMeshData(faceBox: box, points: points)
    }

    /// Maillage du visage : points de repère en coords image normalisées (origine
    /// haut-gauche, y vers le bas) → prêts à projeter sur l'écran pour l'animation
    /// de scan futuriste. Renvoie [] si aucun visage exploitable.
    static func faceLandmarks(in image: UIImage) -> [CGPoint] {
        faceMesh(in: image)?.points ?? []
    }

    /// Visage le plus grand + régions des yeux (coords normalisées Vision, y vers le haut).
    private static func detectFace(in cg: CGImage) -> (box: SkinFaceBox, eyeRegions: [CGRect])? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            return nil
        }
        let bb = face.boundingBox
        let box = SkinFaceBox(x: bb.origin.x, y: bb.origin.y, width: bb.width, height: bb.height)

        // Les points des landmarks sont normalisés DANS la bbox du visage → on les
        // reprojette en coordonnées image normalisées.
        var eyes: [CGRect] = []
        for region in [face.landmarks?.leftEye, face.landmarks?.rightEye].compactMap({ $0 }) {
            let pts = region.normalizedPoints
            guard !pts.isEmpty else { continue }
            let xs = pts.map { bb.minX + CGFloat($0.x) * bb.width }
            let ys = pts.map { bb.minY + CGFloat($0.y) * bb.height }
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { continue }
            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            if !rect.isNull, rect.width > 0, rect.height > 0 { eyes.append(rect) }
        }
        return (box, eyes)
    }

    private static func normalizedImagePoints(from region: VNFaceLandmarkRegion2D, faceBox bb: CGRect) -> [CGPoint] {
        region.normalizedPoints.map { p in
            let nx = bb.minX + CGFloat(p.x) * bb.width
            let nyUp = bb.minY + CGFloat(p.y) * bb.height
            return CGPoint(x: nx, y: 1 - nyUp)
        }
    }

    private static func deduplicated(_ points: [CGPoint]) -> [CGPoint] {
        var out: [CGPoint] = []
        for point in points {
            let alreadyPresent = out.contains {
                abs($0.x - point.x) < 0.0015 && abs($0.y - point.y) < 0.0015
            }
            if !alreadyPresent { out.append(point) }
        }
        return out
    }

    /// Gains de balance des blancs (r,g,b). Échantillonne les pixels clairs et quasi
    /// neutres dans les yeux (= sclère) ; à défaut, gray-world sur toute l'image.
    private static func whiteBalanceGains(_ px: [UInt8], side: Int, eyeRegions: [CGRect]) -> (r: Double, g: Double, b: Double) {
        var sr = 0.0, sg = 0.0, sb = 0.0, n = 0.0

        for region in eyeRegions {
            forEachPixel(px, side: side, in: region) { r, g, b in
                let l = 0.299 * r + 0.587 * g + 0.114 * b
                let chroma = max(r, g, b) - min(r, g, b)
                if l > 0.45 && chroma < 0.14 { sr += r; sg += g; sb += b; n += 1 }
            }
        }

        // Repli gray-world : moyenne de toute l'image (pixels raisonnablement éclairés).
        if n < 8 {
            sr = 0; sg = 0; sb = 0; n = 0
            forEachPixel(px, side: side, in: CGRect(x: 0, y: 0, width: 1, height: 1)) { r, g, b in
                let l = 0.299 * r + 0.587 * g + 0.114 * b
                if l > 0.10 && l < 0.95 { sr += r; sg += g; sb += b; n += 1 }
            }
        }

        guard n > 0 else { return (1, 1, 1) }
        let mr = sr / n, mg = sg / n, mb = sb / n
        let mean = (mr + mg + mb) / 3
        // Gains bornés pour ne pas sur-corriger sur une mauvaise référence.
        func gain(_ c: Double) -> Double { c <= 0.001 ? 1 : min(1.8, max(0.55, mean / c)) }
        return (gain(mr), gain(mg), gain(mb))
    }

    /// Parcourt les pixels d'une région normalisée (y vers le haut) du buffer.
    private static func forEachPixel(_ px: [UInt8], side: Int, in rect: CGRect, _ body: (Double, Double, Double) -> Void) {
        let x0 = max(0, Int(floor(rect.minX * CGFloat(side))))
        let x1 = min(side, Int(ceil(rect.maxX * CGFloat(side))))
        let y0 = max(0, Int(floor((1 - rect.maxY) * CGFloat(side))))
        let y1 = min(side, Int(ceil((1 - rect.minY) * CGFloat(side))))
        guard x0 < x1, y0 < y1 else { return }
        for y in y0..<y1 {
            for x in x0..<x1 {
                let i = (y * side + x) * 4
                body(Double(px[i]) / 255, Double(px[i + 1]) / 255, Double(px[i + 2]) / 255)
            }
        }
    }

    private static func sampleRegions(faceBox: SkinFaceBox?) -> [CGRect] {
        guard let faceBox else {
            return [CGRect(x: 0.24, y: 0.25, width: 0.52, height: 0.50)]
        }

        let f = faceBox.cgRect
        let w = f.width, h = f.height
        return [
            CGRect(x: f.minX + w * 0.20, y: f.minY + h * 0.62, width: w * 0.60, height: h * 0.20),
            CGRect(x: f.minX + w * 0.12, y: f.minY + h * 0.32, width: w * 0.30, height: h * 0.26),
            CGRect(x: f.minX + w * 0.58, y: f.minY + h * 0.32, width: w * 0.30, height: h * 0.26),
            CGRect(x: f.minX + w * 0.34, y: f.minY + h * 0.16, width: w * 0.32, height: h * 0.18)
        ].compactMap { rect in
            let clipped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            return clipped.isNull ? nil : clipped
        }
    }

    private static func collectPixels(_ px: [UInt8], side: Int, regions: [CGRect], gains: (r: Double, g: Double, b: Double), strictSkinFilter: Bool) -> [PixelSample] {
        var samples: [PixelSample] = []

        for rect in regions {
            let x0 = max(0, Int(floor(rect.minX * CGFloat(side))))
            let x1 = min(side, Int(ceil(rect.maxX * CGFloat(side))))
            let y0 = max(0, Int(floor((1 - rect.maxY) * CGFloat(side))))
            let y1 = min(side, Int(ceil((1 - rect.minY) * CGFloat(side))))
            guard x0 < x1, y0 < y1 else { continue }

            for y in y0..<y1 {
                for x in x0..<x1 {
                    let i = (y * side + x) * 4
                    // Application de la balance des blancs avant toute mesure.
                    let r = min(1, Double(px[i]) / 255 * gains.r)
                    let g = min(1, Double(px[i + 1]) / 255 * gains.g)
                    let b = min(1, Double(px[i + 2]) / 255 * gains.b)
                    let l = 0.299 * r + 0.587 * g + 0.114 * b
                    let sample = PixelSample(r: r, g: g, b: b, luma: l)

                    if strictSkinFilter {
                        if isLikelySkin(sample) { samples.append(sample) }
                    } else if isUsableFacePixel(sample) {
                        samples.append(sample)
                    }
                }
            }
        }

        return samples
    }

    private static func isLikelySkin(_ p: PixelSample) -> Bool {
        let sum = max(0.001, p.r + p.g + p.b)
        let nr = p.r / sum
        let ng = p.g / sum
        let maxC = max(p.r, p.g, p.b)
        let minC = min(p.r, p.g, p.b)
        let chroma = maxC - minC

        return p.luma > 0.13 && p.luma < 0.92
            && chroma > 0.025
            && p.r > p.b * 0.74
            && p.g > p.b * 0.62
            && abs(p.r - p.g) < 0.32
            && nr > 0.30 && nr < 0.50
            && ng > 0.24 && ng < 0.43
    }

    private static func isUsableFacePixel(_ p: PixelSample) -> Bool {
        p.luma > 0.11 && p.luma < 0.94 && p.r > p.b * 0.62 && p.g > p.b * 0.52
    }

    private struct PixelSample {
        let r: Double
        let g: Double
        let b: Double
        let luma: Double
        var warmth: Double { r - b }
        var redness: Double { max(0, r - (g + b) / 2) }
    }

    private struct PixelStats {
        let count: Int
        let meanR: Double
        let meanG: Double
        let meanB: Double
        let luma: Double
        let warmth: Double
        let redness: Double
        let lumaStd: Double
        let redStd: Double

        init?(samples: [PixelSample]) {
            guard !samples.isEmpty else { return nil }
            count = samples.count
            let n = Double(samples.count)
            let localMeanR = samples.map(\.r).reduce(0, +) / n
            let localMeanG = samples.map(\.g).reduce(0, +) / n
            let localMeanB = samples.map(\.b).reduce(0, +) / n
            let localLuma = samples.map(\.luma).reduce(0, +) / n
            let localWarmth = samples.map(\.warmth).reduce(0, +) / n
            let localRedness = samples.map(\.redness).reduce(0, +) / n

            meanR = localMeanR
            meanG = localMeanG
            meanB = localMeanB
            luma = localLuma
            warmth = localWarmth
            redness = localRedness
            lumaStd = sqrt(samples.map { pow($0.luma - localLuma, 2) }.reduce(0, +) / n)
            redStd = sqrt(samples.map { pow($0.redness - localRedness, 2) }.reduce(0, +) / n)
        }
    }
}

private extension UIImage {
    func solaAnalysisImage(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let ratio = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: max(1, size.width * ratio), height: max(1, size.height * ratio))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: target)).fill()
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
