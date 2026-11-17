import SwiftUI

typealias GC = GraphicsContext

/// 앱 시작 기준의 상대 시간(초). 큰 절대값으로 sin을 계산할 때 생기는 정밀도 문제를 피한다.
enum AppClock {
    static let start = Date()
    static var now: Double { Date().timeIntervalSince(start) }
}

extension Color {
    init(hex: UInt32, _ alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// 보간 가능한 색
struct RGB {
    var r: Double, g: Double, b: Double

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    static let white = RGB(0xFFFFFF)
    static let black = RGB(0x000000)

    func mix(_ o: RGB, _ t: Double) -> RGB {
        let t = min(1, max(0, t))
        return RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    func scaled(_ k: Double) -> RGB { RGB(r: min(1, r * k), g: min(1, g * k), b: min(1, b * k)) }

    func color(_ a: Double = 1) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

/// 여러 색을 0...1 위에 고르게 놓고 보간
func ramp(_ stops: [RGB], _ t: Double) -> RGB {
    let x = min(1, max(0, t)) * Double(stops.count - 1)
    let i = min(stops.count - 2, Int(x))
    return stops[i].mix(stops[i + 1], x - Double(i))
}

@inline(__always) func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func circlePath(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

/// 시드 고정 난수 — 장식 위치가 실행할 때마다 같도록
struct SplitMix {
    var state: UInt64
    mutating func nextRaw() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func next() -> Double { Double(nextRaw() >> 11) / Double(1 << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

enum Kit {
    static let ground: CGFloat = 114

    static func softDisc(_ c: inout GC, _ p: CGPoint, r: CGFloat, color: Color, alpha: Double) {
        c.fill(circlePath(p, r), with: .radialGradient(
            Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
            center: p, startRadius: 0, endRadius: r))
    }

    /// 빛 번짐 (더해지는 합성)
    static func bloom(_ c: inout GC, _ p: CGPoint, r: CGFloat, color: RGB, alpha: Double) {
        guard alpha > 0.005 else { return }
        var g = c
        g.blendMode = .plusLighter
        g.fill(circlePath(p, r), with: .radialGradient(
            Gradient(stops: [
                .init(color: color.color(alpha), location: 0),
                .init(color: color.color(alpha * 0.35), location: 0.3),
                .init(color: color.color(0), location: 1),
            ]),
            center: p, startRadius: 0, endRadius: r))
    }
}
