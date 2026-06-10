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

struct SkinMetrics: Codable, Equatable {
    var tan: Int        // teinte 0…100
    var glow: Int       // éclat / luminosité 0…100
    var evenness: Int   // uniformité 0…100
    var redness: Int    // rougeur 0…100
    var faceBox: SkinFaceBox? = nil
    var sampleCount: Int? = nil
    var advice: String? = nil   // conseil texte (analyse IA cloud uniquement)

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

        let faceBox = detectFaceBox(in: cg)
        let side = 120
        var px = [UInt8](repeating: 0, count: side * side * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        let regions = sampleRegions(faceBox: faceBox)
        let strict = collectPixels(px, side: side, regions: regions, strictSkinFilter: true)
        let relaxed = strict.count >= 80 ? strict : collectPixels(px, side: side, regions: regions, strictSkinFilter: false)
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

    /// Détection de visage réutilisable (sert à ancrer les annotations sur la photo
    /// même quand les mesures viennent de l'IA cloud).
    static func faceBox(in image: UIImage) -> SkinFaceBox? {
        guard let cg = image.solaAnalysisImage(maxDimension: 1200).cgImage else { return nil }
        return detectFaceBox(in: cg)
    }

    private static func detectFaceBox(in cg: CGImage) -> SkinFaceBox? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            return nil
        }
        let box = face.boundingBox
        return SkinFaceBox(x: box.origin.x, y: box.origin.y, width: box.width, height: box.height)
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

    private static func collectPixels(_ px: [UInt8], side: Int, regions: [CGRect], strictSkinFilter: Bool) -> [PixelSample] {
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
                    let r = Double(px[i]) / 255
                    let g = Double(px[i + 1]) / 255
                    let b = Double(px[i + 2]) / 255
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
