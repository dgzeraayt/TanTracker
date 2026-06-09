import SwiftUI

// Mini-parser de "path data" SVG -> SwiftUI Path.
// Gère M m L l H h V v C c S s Q q T t A a Z z, ce qui couvre tous
// les glyphes d'icônes du design (dont les arcs elliptiques).
enum SVGPath {
    static func path(from d: String) -> Path {
        var path = Path()
        let tokens = tokenize(d)
        var i = 0

        var current = CGPoint.zero
        var start = CGPoint.zero
        var prevCtrl: CGPoint? = nil   // dernier point de contrôle (C/S)
        var prevQCtrl: CGPoint? = nil  // dernier point de contrôle (Q/T)
        var lastCmd: Character = " "

        func num() -> CGFloat {
            defer { i += 1 }
            return i < tokens.count ? (tokens[i].value ?? 0) : 0
        }
        func pt(rel: Bool) -> CGPoint {
            let x = num(); let y = num()
            return rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            var cmd: Character
            if let c = tokens[i].cmd {
                cmd = c
                i += 1
            } else {
                // répétition implicite de la commande précédente
                cmd = lastCmd == "M" ? "L" : (lastCmd == "m" ? "l" : lastCmd)
            }
            let rel = cmd.isLowercase
            let up = Character(cmd.uppercased())

            switch up {
            case "M":
                current = pt(rel: rel)
                start = current
                path.move(to: current)
                prevCtrl = nil; prevQCtrl = nil
            case "L":
                current = pt(rel: rel)
                path.addLine(to: current)
                prevCtrl = nil; prevQCtrl = nil
            case "H":
                let x = num()
                current = CGPoint(x: rel ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                prevCtrl = nil; prevQCtrl = nil
            case "V":
                let y = num()
                current = CGPoint(x: current.x, y: rel ? current.y + y : y)
                path.addLine(to: current)
                prevCtrl = nil; prevQCtrl = nil
            case "C":
                let c1 = pt(rel: rel); let c2 = pt(rel: rel); let end = pt(rel: rel)
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end; prevCtrl = c2; prevQCtrl = nil
            case "S":
                let c1 = (lastCmd == "C" || lastCmd == "c" || lastCmd == "S" || lastCmd == "s")
                    ? reflect(prevCtrl ?? current, about: current) : current
                let c2 = pt(rel: rel); let end = pt(rel: rel)
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end; prevCtrl = c2; prevQCtrl = nil
            case "Q":
                let c = pt(rel: rel); let end = pt(rel: rel)
                path.addQuadCurve(to: end, control: c)
                current = end; prevQCtrl = c; prevCtrl = nil
            case "T":
                let c = (lastCmd == "Q" || lastCmd == "q" || lastCmd == "T" || lastCmd == "t")
                    ? reflect(prevQCtrl ?? current, about: current) : current
                let end = pt(rel: rel)
                path.addQuadCurve(to: end, control: c)
                current = end; prevQCtrl = c; prevCtrl = nil
            case "A":
                let rx = num(); let ry = num(); let rot = num()
                let large = num() != 0; let sweep = num() != 0
                let end = pt(rel: rel)
                addArc(&path, from: current, to: end, rx: rx, ry: ry,
                       xRotDeg: rot, largeArc: large, sweep: sweep)
                current = end; prevCtrl = nil; prevQCtrl = nil
            case "Z":
                path.closeSubpath()
                current = start; prevCtrl = nil; prevQCtrl = nil
            default:
                break
            }
            lastCmd = cmd
        }
        return path
    }

    // MARK: tokenisation
    private struct Token { var cmd: Character?; var value: CGFloat? }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        var numBuf = ""
        func flush() {
            if !numBuf.isEmpty { tokens.append(Token(cmd: nil, value: CGFloat(Double(numBuf) ?? 0))); numBuf = "" }
        }
        let cmds = Set("MmLlHhVvCcSsQqTtAaZz")
        for ch in d {
            if cmds.contains(ch) {
                flush()
                tokens.append(Token(cmd: ch, value: nil))
            } else if ch == "-" || ch == "+" {
                // un signe démarre un nouveau nombre, sauf après 'e' (exposant)
                if !numBuf.isEmpty && numBuf.last != "e" && numBuf.last != "E" { flush() }
                numBuf.append(ch)
            } else if ch == "." {
                // un deuxième point démarre un nouveau nombre
                if numBuf.contains(".") { flush() }
                numBuf.append(ch)
            } else if ch.isNumber || ch == "e" || ch == "E" {
                numBuf.append(ch)
            } else { // espace, virgule...
                flush()
            }
        }
        flush()
        return tokens
    }

    private static func reflect(_ p: CGPoint, about c: CGPoint) -> CGPoint {
        CGPoint(x: 2 * c.x - p.x, y: 2 * c.y - p.y)
    }

    // Arc elliptique -> suite de courbes (algorithme de la spec SVG)
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                               rx: CGFloat, ry: CGFloat, xRotDeg: CGFloat,
                               largeArc: Bool, sweep: Bool) {
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        var rx = abs(rx), ry = abs(ry)
        let phi = xRotDeg * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)

        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p =  cosP * dx + sinP * dy
        let y1p = -sinP * dx + cosP * dy

        var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s; lambda = 1 }

        let sign: CGFloat = (largeArc != sweep) ? 1 : -1
        let num = max(0, rx*rx*ry*ry - rx*rx*y1p*y1p - ry*ry*x1p*x1p)
        let den = rx*rx*y1p*y1p + ry*ry*x1p*x1p
        let co = sign * sqrt(den == 0 ? 0 : num / den)
        let cxp =  co * (rx * y1p / ry)
        let cyp = -co * (ry * x1p / rx)

        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux*vx + uy*vy
            let len = sqrt((ux*ux+uy*uy)*(vx*vx+vy*vy))
            var a = acos(max(-1, min(1, dot / (len == 0 ? 1 : len))))
            if ux*vy - uy*vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp)/rx, (y1p - cyp)/ry)
        var dTheta = angle((x1p - cxp)/rx, (y1p - cyp)/ry, (-x1p - cxp)/rx, (-y1p - cyp)/ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        let segments = Int(ceil(abs(dTheta) / (.pi / 2)))
        let delta = dTheta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(delta / 4)

        var ang = theta1
        var startPt = p0
        for _ in 0..<segments {
            let ang2 = ang + delta
            let cos1 = cos(ang), sin1 = sin(ang)
            let cos2 = cos(ang2), sin2 = sin(ang2)

            let e2x = cosP * rx * cos2 - sinP * ry * sin2 + cx
            let e2y = sinP * rx * cos2 + cosP * ry * sin2 + cy

            let dxp1 = -rx * sin1, dyp1 = ry * cos1
            let c1 = CGPoint(x: startPt.x + t * (cosP * dxp1 - sinP * dyp1),
                             y: startPt.y + t * (sinP * dxp1 + cosP * dyp1))
            let dxp2 = -rx * sin2, dyp2 = ry * cos2
            let c2 = CGPoint(x: e2x - t * (cosP * dxp2 - sinP * dyp2),
                             y: e2y - t * (sinP * dxp2 + cosP * dyp2))
            let end = CGPoint(x: e2x, y: e2y)
            path.addCurve(to: end, control1: c1, control2: c2)
            startPt = end
            ang = ang2
        }
    }
}
