import Foundation
import UIKit

// Sauvegarde/chargement des photos de suivi sur disque.
enum PhotoStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    @discardableResult
    static func save(_ image: UIImage) -> String? {
        let name = UUID().uuidString + ".jpg"
        let prepared = image.solaStorageImage(maxDimension: 1800)
        guard let data = prepared.jpegData(compressionQuality: 0.84) else { return nil }
        do { try data.write(to: dir.appendingPathComponent(name)); return name }
        catch { return nil }
    }

    static func load(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: dir.appendingPathComponent(filename).path)
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
    }
}

private extension UIImage {
    func solaStorageImage(maxDimension: CGFloat) -> UIImage {
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
