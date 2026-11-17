import SwiftUI

// MARK: - 레시피 (디자인 = 레시피 조합)

struct Foliage {
    /// 그늘 → 빛 받는 쪽 순서의 잎 색
    var stops: [RGB]
    /// 새순(가지 끝) 색
    var tip: RGB
    /// 가지 위에 쌓인 눈 (0...1)
    var snow: Double = 0
    /// 흰색 플로킹(인조눈) 정도 (0...1)
    var flock: Double = 0
    var density: Double = 1

    static let fir = Foliage(stops: [RGB(0x071F1B), RGB(0x154535), RGB(0x347457), RGB(0x6B9D71)], tip: RGB(0xB1C794))
    static let deepFir = Foliage(stops: [RGB(0x061A16), RGB(0x103D2F), RGB(0x286047), RGB(0x508766)], tip: RGB(0x9BBA86))
    static let spruce = Foliage(stops: [RGB(0x07171A), RGB(0x173A3A), RGB(0x2F5F5A), RGB(0x6B9A90)], tip: RGB(0xA8CBBE))
}

enum Finish { case glossy, matte, glitter }

struct OrnamentKind {
    var color: RGB
    var finish: Finish
    var size: CGFloat = 1
    var drop = false
    var fluted = false
}

struct RibbonStyle {
    var dark: RGB, mid: RGB, light: RGB
    var width: CGFloat = 3
    var turns: Double = 2.2
}

enum StarStyle { case gold, silver, roseGold, straw, glow, none }

enum BaseStyle {
    case skirt(RGB, trim: RGB)
    case basket, brass, crate, bucket
}

enum LightStyle { case warm, cool, mixed, vintage, rotating, none }

struct TreeRecipe {
    var foliage: Foliage = .fir
    var ornaments: [OrnamentKind] = []
    var ornamentCount = 0
    var ribbon: RibbonStyle?
    var beads: RGB?
    var bows: RGB?
    var lights: LightStyle = .warm
    var lightCount = 80
    var star: StarStyle = .gold
    var base: BaseStyle = .basket
    var gifts = false
    /// 잎 없이 금속 와이어로만 된 트리
    var wire = false
    var seed: UInt64 = 1
}

// MARK: - 원뿔 기하

/// 트리는 3D 원뿔 위의 점들로 만든다. v: 위(0)→아래(1), theta: 둘레 각(π/2 = 정면), rho: 중심(0)→표면(1)
enum Cone {
    static let cx: CGFloat = 50
    static let top: CGFloat = 19
    static let height: CGFloat = 80
    static let maxR: Double = 37
    /// 위에서 살짝 내려다보는 시점
    static let tilt: Double = 0.13

    static func radius(_ v: Double, smooth: Bool = false) -> Double {
        let base = 0.04 + 0.96 * pow(max(0, v), 0.95)
        if smooth { return maxR * max(0, v) * 0.97 }
        let whorl = 1 + 0.085 * sin(v * 38 + 0.8) * min(1, v * 3)
        return maxR * base * whorl
    }

    static func project(_ v: Double, _ theta: Double, _ rho: Double, smooth: Bool = false) -> (p: CGPoint, z: Double) {
        let r = radius(v, smooth: smooth) * rho
        let z = r * sin(theta)
        return (P(cx + CGFloat(r * cos(theta)), top + CGFloat(v) * height + CGFloat(tilt * z)), z)
    }

    static func silhouette(inset: Double) -> Path {
        Path { p in
            let n = 60
            for i in 0...n {
                let v = Double(i) / Double(n)
                let pt = P(cx - CGFloat(radius(v) * inset), top + CGFloat(v) * height)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            for i in 0...24 {
                let th = Double.pi - Double.pi * Double(i) / 24
                p.addLine(to: project(1, th, inset).p)
            }
            for i in stride(from: n, through: 0, by: -1) {
                let v = Double(i) / Double(n)
                p.addLine(to: P(cx + CGFloat(radius(v) * inset), top + CGFloat(v) * height))
            }
            p.closeSubpath()
        }
    }

    /// 표면 법선과 왼쪽 위 조명으로 계산한 밝기 0...1
    static func lambert(_ theta: Double, up: Double = 0.35) -> Double {
        let n = (x: cos(theta), y: -up, z: sin(theta))
        let nl = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        let l = (x: -0.55, y: -0.5, z: 0.67)
        return max(0, (n.x * l.x + n.y * l.y + n.z * l.z) / nl)
    }
}

// MARK: - 모델

final class TreeModel {
    struct Spray { var base: CGPoint; var tip: CGPoint; var shade: Double; var snow: Double; var seed: UInt64 }
    struct Ornament { var p: CGPoint; var r: CGFloat; var kind: OrnamentKind; var seed: UInt64 }
    struct Quad { var path: Path; var color: RGB; var top: CGPoint; var bottom: CGPoint }
    struct Bead { var p: CGPoint; var r: CGFloat; var shade: Double }
    struct Bow { var p: CGPoint; var size: CGFloat; var color: RGB }
    enum Item { case spray(Spray), ornament(Ornament), ribbon(Quad), bead(Bead), bow(Bow) }
    struct Light { var v: Double; var theta: Double; var rho: Double; var tone: Int; var phase: Double; var speed: Double }

    let recipe: TreeRecipe
    private(set) var items: [(z: Double, item: Item)] = []
    private(set) var lights: [Light] = []
    private var decorationSpace: [(CGPoint, CGFloat)] = []

    init(recipe: TreeRecipe, lod: Double) {
        self.recipe = recipe
        var rng = SplitMix(state: recipe.seed &* 7919)
        if !recipe.wire {
            makeSprays(&rng, lod: lod)
            makeCrown(&rng, lod: lod)
            // 장식과 전구는 잎의 LOD와 관계없이 같은 위치를 유지한다.
            rng = SplitMix(state: recipe.seed &* 104729)
            if let color = recipe.bows { makeBows(color) }
            makeOrnaments(&rng)
            if let r = recipe.ribbon { makeRibbon(r) }
            if let b = recipe.beads { makeBeads(b) }
            items.sort { $0.z < $1.z }
        }
        rng = SplitMix(state: recipe.seed &* 15485863)
        makeLights(&rng)
    }

    private func makeSprays(_ rng: inout SplitMix, lod: Double) {
        let f = recipe.foliage
        let n = Int(1250 * f.density * lod)
        for _ in 0..<n {
            let v = sqrt(rng.next())
            let theta = rng.next() * 2 * Double.pi
            let rho = 1 - 0.55 * pow(rng.next(), 1.5)
            if sin(theta) < -0.3 && rho < 0.85 { continue } // 완전히 가려지는 안쪽 뒷가지
            let (tip, z) = Cone.project(v, theta, rho)
            let len = (2.4 + 6.4 * v) * rng.range(0.75, 1.25)
            let c = cos(theta)
            let dx = len * c * 0.95
            let dy = len * (0.12 + 0.35 * (1 - abs(c))) + rng.range(-0.65, 0.65)
            let base = P(tip.x - CGFloat(dx), tip.y - CGFloat(dy))
            let ao = pow(rho, 2.2)
            var shade = 0.06 + 0.94 * ao * (0.25 + 0.75 * Cone.lambert(theta))
            shade += rng.range(-0.07, 0.07)
            let snow = f.snow * (0.45 + 0.55 * shade) * (rho > 0.8 ? 1 : 0.4)
            items.append((z, .spray(Spray(base: base, tip: tip, shade: shade, snow: snow, seed: rng.nextRaw()))))
        }
    }

    /// 꼭대기: 곧게 선 중심 순과 그 주변에 모인 작은 가지들 (별과 트리를 이어 준다)
    private func makeCrown(_ rng: inout SplitMix, lod: Double) {
        let f = recipe.foliage
        let count = Int(70 * lod) + 14
        for _ in 0..<count {
            let v = 0.015 + 0.2 * rng.next()
            let theta = rng.next() * 2 * Double.pi
            let axis = P(Cone.cx, Cone.top + CGFloat(v) * Cone.height)
            let len = (1.8 + 15 * v) * rng.range(0.8, 1.2)
            let c = cos(theta)
            let tip = P(axis.x + CGFloat(len * c * 0.9), axis.y + CGFloat(len * (0.04 + 0.16 * (1 - abs(c)))))
            var shade = 0.12 + 0.88 * (0.3 + 0.7 * Cone.lambert(theta))
            shade += rng.range(-0.06, 0.06)
            let snow = f.snow * (0.45 + 0.55 * shade)
            items.append((sin(theta) * len, .spray(Spray(base: axis, tip: tip, shade: shade, snow: snow, seed: rng.nextRaw()))))
        }
        items.append((0.5, .spray(Spray(base: P(Cone.cx, Cone.top + 7), tip: P(Cone.cx, Cone.top - 2.6),
                                        shade: 0.7, snow: f.snow * 0.4, seed: rng.nextRaw()))))
    }

    private func makeBows(_ color: RGB) {
        for (v, theta) in [(0.27, 1.6), (0.45, 2.4), (0.61, 0.7), (0.77, 1.95), (0.9, 0.55)] {
            let (p, z) = Cone.project(v, theta, 1.01)
            let size = CGFloat(1.15 + v * 1.1)
            decorationSpace.append((P(p.x, p.y + size * 0.4), size * 1.6))
            items.append((z + 3, .bow(Bow(p: p, size: size, color: color))))
        }
    }

    private func makeOrnaments(_ rng: inout SplitMix) {
        guard !recipe.ornaments.isEmpty else { return }
        var placed: [(CGPoint, CGFloat)] = []
        var attempts = 0
        while placed.count < recipe.ornamentCount && attempts < 4000 {
            attempts += 1
            let kind = recipe.ornaments[placed.count % recipe.ornaments.count]
            // 높이별로 고르게 배치해 꼭대기에도 작은 장식이 남도록 한다.
            let band = (Double(placed.count) + rng.next()) / Double(max(1, recipe.ornamentCount))
            let v = min(0.93, max(0.15, 0.15 + 0.78 * pow(band, 0.72) + rng.range(-0.045, 0.045)))
            let theta = Double.pi * rng.range(0.1, 0.9)
            let rho = rng.range(0.9, 0.98)
            var (p, z) = Cone.project(v, theta, rho)
            let r = CGFloat((1.35 + 1.5 * v) * rng.range(0.85, 1.15) * (0.78 + 0.22 * sin(theta))) * kind.size
            p.y += r * 0.5
            if placed.contains(where: { hypot($0.0.x - p.x, $0.0.y - p.y) < ($0.1 + r) * 1.15 + 1.2 }) { continue }
            if decorationSpace.contains(where: { hypot($0.0.x - p.x, $0.0.y - p.y) < $0.1 + r + 0.5 }) { continue }
            placed.append((p, r))
            items.append((z + 2.6, .ornament(Ornament(p: p, r: r, kind: kind, seed: rng.nextRaw()))))
        }
    }

    private func makeRibbon(_ style: RibbonStyle) {
        let steps = 320
        var prev: (top: CGPoint, bottom: CGPoint, z: Double)?
        for i in 0...steps {
            let s = Double(i) / Double(steps)
            let v = 0.1 + 0.84 * s
            let theta = 2.4 - s * style.turns * 2 * Double.pi
            let rho = 0.97 + 0.03 * sin(s * 60)
            let (p, z) = Cone.project(v, theta, rho)
            let w = style.width * CGFloat(0.6 + 0.6 * v)
            let top = P(p.x, p.y - w / 2), bottom = P(p.x, p.y + w / 2)
            if let pr = prev, z > 1.5 && pr.z > 1.5 {
                let light = Cone.lambert(theta, up: 0.15)
                let facing = max(0, sin(theta))
                var col = ramp([style.dark, style.mid, style.light], 0.15 + 0.85 * light * (0.4 + 0.6 * facing))
                if light > 0.82 { col = col.mix(.white, (light - 0.82) * 1.6) }
                // 이음새가 보이지 않도록 살짝 겹쳐 그린다
                let dxT = (top.x - pr.top.x) * 0.25, dxB = (bottom.x - pr.bottom.x) * 0.25
                var quad = Path()
                quad.addLines([pr.top, P(top.x + dxT, top.y), P(bottom.x + dxB, bottom.y), pr.bottom])
                quad.closeSubpath()
                items.append(((z + pr.z) / 2 + 1.2, .ribbon(Quad(path: quad, color: col, top: pr.top, bottom: pr.bottom))))
            }
            prev = (top, bottom, z)
        }
    }

    private func makeBeads(_ color: RGB) {
        let count = 420
        var lastBead: CGPoint?
        for i in 0..<count {
            let s = Double(i) / Double(count)
            let v = 0.12 + 0.82 * s
            let theta = 0.9 - s * 3.1 * 2 * Double.pi
            guard sin(theta) > 0.22 else { lastBead = nil; continue }
            let (p, z) = Cone.project(v, theta, 0.99)
            let bp = P(p.x, p.y + CGFloat(1.2 * sin(theta * 2) * v))
            if let lb = lastBead, hypot(lb.x - bp.x, lb.y - bp.y) < 1.0 { continue }
            lastBead = bp
            items.append((z + 1.0, .bead(Bead(p: bp, r: 0.48, shade: Cone.lambert(theta)))))
        }
    }

    private func makeLights(_ rng: inout SplitMix) {
        guard recipe.lights != .none else { return }
        let n = recipe.lightCount
        for i in 0..<n {
            if recipe.lights == .rotating || recipe.wire {
                let s = (Double(i) + 0.5) / Double(n)
                lights.append(Light(v: 0.04 + 0.94 * s, theta: s * 6.5 * 2 * Double.pi, rho: 1.02, tone: i,
                                    phase: rng.range(0, 6.28), speed: rng.range(1, 2.4)))
            } else {
                lights.append(Light(v: 0.05 + 0.92 * sqrt(rng.next()), theta: rng.next() * 2 * Double.pi,
                                    rho: rng.range(0.88, 1.0), tone: Int(rng.next() * 1000),
                                    phase: rng.range(0, 6.28), speed: rng.range(0.6, 1.8)))
            }
        }
    }

    // MARK: 정적 레이어 (캐시되어 한 번만 그림)

    func drawStatic(_ c: inout GC) {
        if recipe.wire {
            drawWire(&c)
            return
        }
        if case .skirt = recipe.base {
            Bases.draw(&c, recipe.base)
            Bases.trunk(&c, bottom: 106.6)
        } else {
            Bases.trunk(&c, bottom: 101)
            Bases.draw(&c, recipe.base)
        }
        let f = recipe.foliage
        let sil = Cone.silhouette(inset: 0.8)
        var deep = f.stops[0].mix(f.stops[1], 0.3)
        if f.flock > 0 { deep = deep.mix(RGB(0x9AA39C), f.flock * 0.5) }
        c.fill(sil, with: .linearGradient(Gradient(colors: [deep.scaled(1.2).color(), deep.color()]),
                                          startPoint: P(30, 20), endPoint: P(70, 100)))
        // 중심 줄기(리더)
        var leader = Path()
        leader.addLines([P(49.45, Cone.top + 16), P(50.55, Cone.top + 16), P(50.12, Cone.top - 2.4), P(49.88, Cone.top - 2.4)])
        leader.closeSubpath()
        c.fill(leader, with: .color(f.stops[1].mix(RGB(0x4A3A22), 0.4).color()))
        for entry in items {
            switch entry.item {
            case .spray(let s): drawSpray(&c, s)
            case .ornament(let o): Ornaments.draw(&c, o.p, r: o.r, kind: o.kind, seed: o.seed)
            case .bow(let b): Ornaments.bow(&c, b.p, size: b.size, color: b.color)
            case .ribbon(let q):
                c.fill(q.path, with: .linearGradient(Gradient(stops: [
                    .init(color: q.color.scaled(0.62).color(), location: 0),
                    .init(color: q.color.mix(.white, 0.12).color(), location: 0.4),
                    .init(color: q.color.color(), location: 0.65),
                    .init(color: q.color.scaled(0.6).color(), location: 1),
                ]), startPoint: q.top, endPoint: q.bottom))
            case .bead(let b):
                let col = RGB(0xF3D58A).scaled(0.55 + 0.6 * b.shade)
                c.fill(circlePath(b.p, b.r), with: .radialGradient(
                    Gradient(colors: [col.mix(.white, 0.6).color(), col.color(), col.scaled(0.5).color()]),
                    center: P(b.p.x - b.r * 0.35, b.p.y - b.r * 0.35), startRadius: 0, endRadius: b.r * 1.5))
            }
        }
        if recipe.gifts { Gifts.draw(&c) }
    }

    private func drawSpray(_ c: inout GC, _ s: Spray) {
        let f = recipe.foliage
        let dx = s.tip.x - s.base.x, dy = s.tip.y - s.base.y
        let len = hypot(dx, dy)
        guard len > 0.3 else { return }
        let ux = dx / len, uy = dy / len
        var rng = SplitMix(state: s.seed)
        var body = Path(), tips = Path()
        body.move(to: s.base)
        body.addLine(to: s.tip)
        let n = max(6, Int(len * 2.3))
        for i in 0..<n {
            let t = (CGFloat(i) + 0.5) / CGFloat(n)
            let q = P(s.base.x + dx * t, s.base.y + dy * t)
            let nl = len * 0.27 * (1 - 0.62 * t) + 0.32
            for side in [-1.0, 1.0] {
                let a = (1.05 - 0.35 * Double(t)) * side + rng.range(-0.14, 0.14)
                let ca = CGFloat(cos(a)), sa = CGFloat(sin(a))
                var vx = ux * ca - uy * sa, vy = ux * sa + uy * ca + 0.12
                let m = hypot(vx, vy)
                vx /= m; vy /= m
                let l = nl * CGFloat(rng.range(0.8, 1.15))
                let end = P(q.x + vx * l, q.y + vy * l)
                let control = P(q.x + vx * l * 0.55, q.y + vy * l * 0.55 - l * 0.14)
                if t > 0.68 {
                    tips.move(to: q); tips.addQuadCurve(to: end, control: control)
                } else {
                    body.move(to: q); body.addQuadCurve(to: end, control: control)
                }
            }
        }
        tips.move(to: s.tip)
        tips.addLine(to: P(s.tip.x + ux * 0.9, s.tip.y + uy * 0.9 + 0.15))

        var col = ramp(f.stops, s.shade)
        var tipCol = col.mix(f.tip, 0.18 + 0.24 * s.shade)
        if f.flock > 0 {
            let w = RGB(0xF2F5F2).scaled(0.62 + 0.42 * s.shade)
            col = col.mix(w, f.flock * 0.7)
            tipCol = tipCol.mix(w, f.flock * 0.95)
        }
        let under = f.stops[0].scaled(0.6).color(0.42)
        let wide = StrokeStyle(lineWidth: 0.43, lineCap: .round)
        let thin = StrokeStyle(lineWidth: 0.22, lineCap: .round)
        c.stroke(body, with: .color(under), style: wide)
        c.stroke(tips, with: .color(under), style: wide)
        c.stroke(body, with: .color(col.color()), style: thin)
        c.stroke(tips, with: .color(tipCol.color()), style: thin)
        if s.snow > 0.05 && s.shade > 0.3 {
            // 가지 윗면에 얹힌 울퉁불퉁한 눈 — 작은 원 여러 개를 겹쳐 만든다
            let top = RGB(0xFDFEFF).mix(RGB(0xC9D7E4), 1 - s.shade)
            let bottom = top.mix(RGB(0x8FA5BA), 0.55)
            var clump = Path()
            let count = max(2, Int(len * 0.9 * s.snow))
            for _ in 0..<count {
                let t = CGFloat(rng.range(0.25, 0.95))
                let q = P(s.base.x + dx * t + CGFloat(rng.range(-0.4, 0.4)), s.base.y + dy * t - CGFloat(rng.range(0.1, 0.5)))
                let r = CGFloat(rng.range(0.28, 0.6)) * CGFloat(0.7 + 0.5 * s.snow)
                clump.addEllipse(in: CGRect(x: q.x - r * 1.2, y: q.y - r * 0.8, width: r * 2.4, height: r * 1.6))
            }
            let bb = clump.boundingRect
            c.fill(clump, with: .linearGradient(Gradient(colors: [top.color(), bottom.color()]),
                                                startPoint: P(bb.midX, bb.minY), endPoint: P(bb.midX, bb.maxY)))
        }
    }

    private func drawWire(_ c: inout GC) {
        let gold = RGB(0xE8C870), dimGold = RGB(0xB08A3E)
        func proj(_ v: Double, _ th: Double) -> (p: CGPoint, z: Double) { Cone.project(v, th, 1, smooth: true) }
        let bottomV = 0.98
        var backPath = Path(), frontPath = Path()
        // 세로 갈비
        for i in 0..<10 {
            let th = Double(i) / 10 * 2 * Double.pi + 0.15
            var rib = Path()
            rib.move(to: proj(0, th).p)
            rib.addLine(to: proj(bottomV, th).p)
            if sin(th) >= 0 { frontPath.addPath(rib) } else { backPath.addPath(rib) }
        }
        // 아래 고리와 중심으로 이어지는 살
        let hub = P(50, Cone.top + CGFloat(bottomV) * Cone.height - 4)
        for i in 0...60 {
            let th = Double(i) / 60 * 2 * Double.pi
            let th2 = Double(i + 1) / 60 * 2 * Double.pi
            var seg = Path()
            seg.move(to: proj(bottomV, th).p)
            seg.addLine(to: proj(bottomV, th2).p)
            if sin((th + th2) / 2) >= 0 { frontPath.addPath(seg) } else { backPath.addPath(seg) }
        }
        for i in 0..<4 {
            let th = Double(i) * Double.pi / 2 + Double.pi / 4
            var spoke = Path()
            spoke.move(to: hub)
            spoke.addLine(to: proj(bottomV, th).p)
            if sin(th) >= 0 { frontPath.addPath(spoke) } else { backPath.addPath(spoke) }
        }
        // 나선 와이어
        var spiralBack = Path(), spiralFront = Path()
        for strand in 0..<2 {
            var prevFront: Bool?
            for i in 0...400 {
                let sv = Double(i) / 400
                let th = sv * 6.5 * 2 * Double.pi + Double(strand) * Double.pi
                let (pt, z) = Cone.project(0.04 + 0.94 * sv, th, 1.02, smooth: true)
                let isFront = z >= 0
                if isFront != prevFront {
                    if isFront { spiralFront.move(to: pt) } else { spiralBack.move(to: pt) }
                } else {
                    if isFront { spiralFront.addLine(to: pt) } else { spiralBack.addLine(to: pt) }
                }
                prevFront = isFront
            }
        }
        c.stroke(backPath, with: .color(dimGold.color(0.35)), lineWidth: 0.35)
        c.stroke(spiralBack, with: .color(dimGold.color(0.3)), lineWidth: 0.3)

        // 중심 기둥과 받침
        let pole = CGRect(x: 49.45, y: Cone.top, width: 1.1, height: 109.5 - Cone.top)
        c.fill(Path(pole), with: .linearGradient(Bases.gradient([0x6B4E16, 0xFFF0B8, 0xB8923E, 0x5A4012]),
                                                 startPoint: P(pole.minX, 0), endPoint: P(pole.maxX, 0)))
        let dome = Bases.Vessel(top: 108.6, bottom: Kit.ground) { t in 1.4 + 8.6 * sqrt(t) }
        c.fill(dome.body, with: .linearGradient(Bases.gradient([0x3E2A0C, 0x9C7424, 0xFBEAB0, 0xD6AE4A, 0x8A6420, 0x2E1F08]),
                                                startPoint: P(40, 0), endPoint: P(60, 0)))
        var hl = c
        hl.clip(to: dome.body)
        Kit.softDisc(&hl, P(46.5, 110.6), r: 2.6, color: .white, alpha: 0.45)
        c.stroke(dome.ring(1), with: .color(RGB(0x4A3410).color(0.8)), lineWidth: 0.4)
        c.fill(Path(ellipseIn: CGRect(x: 48.6, y: 107.9, width: 2.8, height: 1.3)), with: .linearGradient(
            Bases.gradient([0x6B4E16, 0xFFF0B8, 0x8A6420]), startPoint: P(48.6, 0), endPoint: P(51.4, 0)))

        c.stroke(frontPath, with: .color(gold.color(0.8)), lineWidth: 0.42)
        c.stroke(spiralFront, with: .color(gold.color(0.9)), lineWidth: 0.45)
    }

    // MARK: 동적 레이어 (매 프레임)

    func drawDynamic(_ c: inout GC, _ t: Double) {
        drawLights(&c, t)
        let starCenter = P(Cone.cx, Cone.top - 3.6)
        if recipe.star != .none { Stars.collar(&c, recipe.star, top: starCenter.y + 1.6, bottom: Cone.top + 2.2) }
        Stars.draw(&c, recipe.star, center: starCenter, r: 6.4, t: t)
    }

    private func drawLights(_ c: inout GC, _ t: Double) {
        let spin = (recipe.lights == .rotating) ? t * 0.55 : (recipe.wire ? t * 0.25 : 0)
        let vintage: [RGB] = [RGB(0xFF3B30), RGB(0x34C759), RGB(0x2F7BFF), RGB(0xFF9500), RGB(0xFFD60A)]
        for l in lights {
            let theta = l.theta + spin
            let (p, z) = Cone.project(l.v, theta, l.rho, smooth: recipe.wire)
            let r = Cone.radius(l.v, smooth: recipe.wire) * l.rho
            let depth = r > 0.01 ? z / r : 1 // -1(뒤) ... 1(앞)
            var vis = depth >= 0 ? 1.0 : max(0.0, 0.3 + depth * 0.35)
            if recipe.wire { vis = depth >= 0 ? 1 : 0.35 }
            guard vis > 0.02 else { continue }
            let tw = 0.78 + 0.22 * sin(t * l.speed + l.phase)
            let k = vis * tw
            switch recipe.lights {
            case .vintage:
                drawC9(&c, p, color: vintage[l.tone % vintage.count], k: k, depth: depth)
            default:
                let warm = (core: RGB(0xFFF4DC), glow: RGB(0xFFA43C))
                let cool = (core: RGB(0xF2F8FF), glow: RGB(0x7CC0FF))
                let tone = recipe.lights == .cool || (recipe.lights == .mixed && l.tone % 3 == 0) ? cool : warm
                let size: CGFloat = recipe.wire ? 0.45 : 0.55
                Kit.bloom(&c, p, r: size * 8.5, color: tone.glow, alpha: 0.4 * k)
                Kit.bloom(&c, p, r: size * 2.6, color: tone.core, alpha: 0.95 * k)
                c.fill(circlePath(p, size * 0.62), with: .color(tone.core.color(min(1, 0.55 + 0.45 * k))))
            }
        }
    }

    /// 빈티지 C9 전구 (색유리 전구)
    private func drawC9(_ c: inout GC, _ p: CGPoint, color: RGB, k: Double, depth: Double) {
        Kit.bloom(&c, p, r: 6.5, color: color, alpha: 0.4 * k)
        let w: CGFloat = 0.95, h: CGFloat = 1.6
        var bulb = Path()
        bulb.move(to: P(p.x, p.y + h))
        bulb.addCurve(to: P(p.x - w, p.y - h * 0.15), control1: P(p.x - w * 0.5, p.y + h * 0.75), control2: P(p.x - w, p.y + h * 0.3))
        bulb.addCurve(to: P(p.x + w, p.y - h * 0.15), control1: P(p.x - w, p.y - h * 0.75), control2: P(p.x + w, p.y - h * 0.75))
        bulb.addCurve(to: P(p.x, p.y + h), control1: P(p.x + w, p.y + h * 0.3), control2: P(p.x + w * 0.5, p.y + h * 0.75))
        c.fill(Path(CGRect(x: p.x - 0.55, y: p.y - h * 0.75, width: 1.1, height: 0.8)), with: .color(RGB(0x1E3A22).color()))
        c.fill(bulb, with: .radialGradient(
            Gradient(colors: [color.mix(.white, 0.75).color(), color.color(), color.scaled(0.55).color()]),
            center: P(p.x - 0.25, p.y - 0.1), startRadius: 0, endRadius: 2))
        Kit.bloom(&c, P(p.x, p.y + 0.2), r: 1.8, color: color.mix(.white, 0.5), alpha: 0.5 * k)
    }
}

// MARK: - 오너먼트

enum Ornaments {
    /// 금색 테두리와 접힌 꼬리가 있는 작은 벨벳 리본.
    static func bow(_ c: inout GC, _ p: CGPoint, size s: CGFloat, color: RGB) {
        Kit.softDisc(&c, P(p.x + s * 0.3, p.y + s * 0.7), r: s * 2.3, color: .black, alpha: 0.3)
        let edge = RGB(0xE5C88B)
        for side: CGFloat in [-1, 1] {
            var tail = Path()
            tail.move(to: p)
            tail.addQuadCurve(to: P(p.x + side * s * 1.0, p.y + s * 2.3),
                              control: P(p.x + side * s * 0.25, p.y + s * 1.5))
            tail.addLines([P(p.x + side * s * 0.48, p.y + s * 2.05),
                           P(p.x + side * s * 0.05, p.y + s * 2.4),
                           P(p.x - side * s * 0.25, p.y + s * 0.3)])
            tail.closeSubpath()
            c.fill(tail, with: .linearGradient(Gradient(colors: [color.scaled(0.55).color(), color.color(), color.scaled(0.6).color()]),
                                               startPoint: p, endPoint: P(p.x, p.y + s * 2.4)))
            c.stroke(tail, with: .color(edge.color(0.6)), lineWidth: 0.1)
            var loop = Path()
            loop.move(to: p)
            loop.addCurve(to: P(p.x + side * s * 1.7, p.y - s * 0.7),
                          control1: P(p.x + side * s * 0.7, p.y - s * 0.8),
                          control2: P(p.x + side * s * 1.7, p.y - s * 1.25))
            loop.addCurve(to: p, control1: P(p.x + side * s * 2.1, p.y + s * 0.85),
                          control2: P(p.x + side * s * 0.65, p.y + s * 0.45))
            c.fill(loop, with: .linearGradient(Gradient(stops: [
                .init(color: color.mix(RGB(0xF6B9A5), 0.4).color(), location: 0),
                .init(color: color.color(), location: 0.45),
                .init(color: color.scaled(0.45).color(), location: 1),
            ]), startPoint: P(p.x, p.y - s), endPoint: P(p.x, p.y + s * 0.6)))
            c.stroke(loop, with: .color(edge.color(0.75)), style: StrokeStyle(lineWidth: 0.12, lineJoin: .round))
            var crease = Path()
            crease.move(to: P(p.x + side * s * 0.25, p.y))
            crease.addQuadCurve(to: P(p.x + side * s * 1.4, p.y - s * 0.25),
                                control: P(p.x + side * s * 0.85, p.y - s * 0.4))
            c.stroke(crease, with: .color(color.scaled(0.35).color(0.7)), lineWidth: 0.17)
        }
        c.fill(Path(roundedRect: CGRect(x: p.x - s * 0.3, y: p.y - s * 0.3, width: s * 0.6, height: s * 0.65),
                    cornerRadius: s * 0.13),
               with: .linearGradient(Gradient(colors: [edge.color(), color.color(), color.scaled(0.6).color()]),
                                     startPoint: P(p.x - s * 0.3, p.y), endPoint: P(p.x + s * 0.3, p.y)))
    }

    static func dropPath(_ p: CGPoint, _ r: CGFloat) -> Path {
        let k: CGFloat = 0.5523
        return Path { path in
            path.move(to: P(p.x - r, p.y))
            path.addCurve(to: P(p.x, p.y - r), control1: P(p.x - r, p.y - k * r), control2: P(p.x - k * r, p.y - r))
            path.addCurve(to: P(p.x + r, p.y), control1: P(p.x + k * r, p.y - r), control2: P(p.x + r, p.y - k * r))
            path.addCurve(to: P(p.x, p.y + 1.8 * r), control1: P(p.x + r, p.y + 0.65 * r), control2: P(p.x + 0.22 * r, p.y + 1.15 * r))
            path.addCurve(to: P(p.x - r, p.y), control1: P(p.x - 0.22 * r, p.y + 1.15 * r), control2: P(p.x - r, p.y + 0.65 * r))
            path.closeSubpath()
        }
    }

    static func draw(_ c: inout GC, _ p: CGPoint, r: CGFloat, kind k: OrnamentKind, seed: UInt64) {
        // 가지에 드리운 그림자
        Kit.softDisc(&c, P(p.x + r * 0.35, p.y + r * 0.6), r: r * 1.45, color: .black, alpha: 0.5)
        let capTop = p.y - r * 1.12
        var hook = Path()
        hook.move(to: P(p.x, capTop))
        hook.addLine(to: P(p.x - 0.15, capTop - 1.3))
        c.stroke(hook, with: .color(Color(white: 0.8, opacity: 0.5)), lineWidth: 0.16)

        let body = k.drop ? dropPath(p, r) : circlePath(p, r)
        let glossy = k.finish == .glossy
        let light = k.color.mix(.white, glossy ? 0.6 : 0.28)
        let dark = k.color.scaled(glossy ? 0.32 : 0.5)
        let hl = P(p.x - r * 0.38, p.y - r * 0.42)
        c.fill(body, with: .radialGradient(Gradient(stops: [
            .init(color: light.color(), location: 0),
            .init(color: k.color.color(), location: glossy ? 0.3 : 0.4),
            .init(color: dark.color(), location: 0.88),
            .init(color: dark.scaled(0.7).color(), location: 1),
        ]), center: hl, startRadius: 0, endRadius: r * 1.8))

        var inner = c
        inner.clip(to: body)
        if k.fluted {
            for i in -3...3 {
                let x = CGFloat(i) / 4
                var rib = Path()
                rib.move(to: P(p.x + x * r * 0.24, p.y - r))
                rib.addCurve(to: P(p.x + x * r * 0.22, p.y + r * (k.drop ? 1.8 : 1)),
                             control1: P(p.x + x * r * 1.45, p.y - r * 0.5),
                             control2: P(p.x + x * r * 1.45, p.y + r * 0.6))
                inner.stroke(rib, with: .color(k.color.scaled(0.35).color(0.45)), lineWidth: r * 0.08)
                inner.stroke(rib, with: .color(RGB(0xFFF1CF).color(0.4)), lineWidth: r * 0.025)
            }
        }
        // 아래쪽 반사광
        Kit.softDisc(&inner, P(p.x + r * 0.5, p.y + r * 0.7), r: r * 0.75, color: k.color.mix(.white, 0.35).color(), alpha: 0.4)
        switch k.finish {
        case .glossy:
            inner.fill(Path(ellipseIn: CGRect(x: hl.x - r * 0.22, y: hl.y - r * 0.13, width: r * 0.44, height: r * 0.27)),
                       with: .color(.white.opacity(0.9)))
            inner.fill(circlePath(P(hl.x + r * 0.36, hl.y + r * 0.04), r * 0.07), with: .color(.white.opacity(0.7)))
        case .matte:
            Kit.softDisc(&inner, hl, r: r * 0.75, color: .white, alpha: 0.28)
        case .glitter:
            Kit.softDisc(&inner, hl, r: r * 0.7, color: .white, alpha: 0.3)
            var rng = SplitMix(state: seed)
            for _ in 0..<Int(18 * r) {
                let a = rng.next() * 2 * Double.pi, d = sqrt(rng.next()) * Double(r)
                let q = P(p.x + CGFloat(cos(a) * d), p.y + CGFloat(sin(a) * d) * (k.drop ? 1.4 : 1))
                let bright = rng.next()
                inner.fill(circlePath(q, r * CGFloat(rng.range(0.04, 0.08))),
                           with: .color(k.color.mix(.white, 0.5 + 0.5 * bright).color(0.35 + 0.6 * bright)))
            }
        }
        // 금속 캡
        let capRect = CGRect(x: p.x - r * 0.27, y: capTop, width: r * 0.54, height: r * 0.3)
        c.fill(Path(roundedRect: capRect, cornerRadius: r * 0.06), with: .linearGradient(
            Gradient(colors: [RGB(0x7A5D24).color(), RGB(0xF5E3A5).color(), RGB(0x8E6E2E).color()]),
            startPoint: P(capRect.minX, 0), endPoint: P(capRect.maxX, 0)))
    }
}

// MARK: - 별

enum Stars {
    static func draw(_ c: inout GC, _ style: StarStyle, center p: CGPoint, r: CGFloat, t: Double) {
        let pulse = 0.85 + 0.15 * sin(t * 1.8)
        switch style {
        case .none: return
        case .gold:
            Kit.bloom(&c, p, r: r * 3.0, color: RGB(0xFFC45C), alpha: 0.35 * pulse)
            bevel(&c, p, r, light: RGB(0xFFF1BE), mid: RGB(0xF0C04A), dark: RGB(0x9A6A12))
            flare(&c, p, r, RGB(0xFFF0C8), 0.55 * pulse)
        case .silver:
            Kit.bloom(&c, p, r: r * 3.0, color: RGB(0xBFE0FF), alpha: 0.3 * pulse)
            bevel(&c, p, r, light: RGB(0xFFFFFF), mid: RGB(0xC9D3DC), dark: RGB(0x6C7A86))
            flare(&c, p, r, RGB(0xEAF5FF), 0.55 * pulse)
        case .roseGold:
            Kit.bloom(&c, p, r: r * 3.0, color: RGB(0xFFB8A0), alpha: 0.3 * pulse)
            bevel(&c, p, r, light: RGB(0xFFE6DA), mid: RGB(0xE3A48C), dark: RGB(0x8E5643))
            flare(&c, p, r, RGB(0xFFE9DF), 0.5 * pulse)
        case .glow:
            Kit.bloom(&c, p, r: r * 3.4, color: RGB(0xFFB547), alpha: 0.5 * pulse)
            bevel(&c, p, r * 0.92, light: RGB(0xFFFFFF), mid: RGB(0xFFF0C4), dark: RGB(0xF5C46A))
            Kit.bloom(&c, p, r: r * 1.6, color: RGB(0xFFF6E0), alpha: 0.6 * pulse)
            flare(&c, p, r * 1.3, RGB(0xFFF4D8), 0.75 * pulse)
        case .straw:
            Kit.bloom(&c, p, r: r * 2.6, color: RGB(0xFFC878), alpha: 0.22 * pulse)
            let star = starPath(p, outer: r * 1.05, inner: r * 0.42, points: 8, rotation: -Double.pi / 2)
            c.fill(star, with: .linearGradient(Gradient(colors: [RGB(0xF6E2B0).color(), RGB(0xC9A060).color()]),
                                               startPoint: P(p.x - r, p.y - r), endPoint: P(p.x + r, p.y + r)))
            for i in 0..<8 {
                let a = -Double.pi / 2 + Double(i) * Double.pi / 4
                var l = Path()
                l.move(to: p)
                l.addLine(to: P(p.x + r * 1.05 * CGFloat(cos(a)), p.y + r * 1.05 * CGFloat(sin(a))))
                c.stroke(l, with: .color(RGB(0x9C7438).color(0.6)), lineWidth: 0.25)
            }
            c.stroke(star, with: .color(RGB(0x8E6A30).color(0.7)), lineWidth: 0.3)
            c.fill(circlePath(p, r * 0.16), with: .color(RGB(0xB3261E).color()))
        }
    }

    /// 별을 꼭대기 순에 끼우는 금속 받침
    static func collar(_ c: inout GC, _ style: StarStyle, top: CGFloat, bottom: CGFloat) {
        let stops: [UInt32]
        switch style {
        case .silver: stops = [0x5E6A74, 0xF2F6F9, 0x9AA6B0, 0x4E5860]
        case .roseGold: stops = [0x7A4A3A, 0xFFE2D4, 0xC98E78, 0x6A3E30]
        case .straw: stops = [0x6A4A22, 0xE8CC8C, 0xA88048, 0x5A3E1C]
        default: stops = [0x6B4E16, 0xFFF0B8, 0xC9A040, 0x5A4012]
        }
        var p = Path()
        p.addLines([P(49.05, top), P(50.95, top), P(50.7, bottom), P(49.3, bottom)])
        p.closeSubpath()
        c.fill(p, with: .linearGradient(Gradient(colors: stops.map { RGB($0).color() }), startPoint: P(49, 0), endPoint: P(51, 0)))
        for y in stride(from: top + 0.8, to: bottom - 0.3, by: 0.9) {
            var ring = Path()
            ring.move(to: P(49.1, y))
            ring.addQuadCurve(to: P(50.9, y), control: P(50, y + 0.35))
            c.stroke(ring, with: .color(.black.opacity(0.25)), lineWidth: 0.18)
        }
    }

    static func starPath(_ center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int = 5, rotation: Double = -Double.pi / 2) -> Path {
        Path { p in
            for i in 0..<(points * 2) {
                let rr = i.isMultiple(of: 2) ? outer : inner
                let a = rotation + Double(i) * Double.pi / Double(points)
                let pt = P(center.x + rr * CGFloat(cos(a)), center.y + rr * CGFloat(sin(a)))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }

    /// 각진 면마다 명암이 다른 입체 별
    static func bevel(_ c: inout GC, _ p: CGPoint, _ r: CGFloat, light: RGB, mid: RGB, dark: RGB) {
        let inner = r * 0.44
        func pt(_ a: Double, _ rr: CGFloat) -> CGPoint { P(p.x + rr * CGFloat(cos(a)), p.y + rr * CGFloat(sin(a))) }
        let lightDir = -3 * Double.pi / 4
        for i in 0..<5 {
            let a = -Double.pi / 2 + Double(i) * 2 * Double.pi / 5
            let tip = pt(a, r)
            let left = pt(a - Double.pi / 5, inner), right = pt(a + Double.pi / 5, inner)
            for (j, side) in [left, right].enumerated() {
                let faceAngle = a + (j == 0 ? -0.5 : 0.5)
                let b = 0.5 + 0.5 * cos(faceAngle - lightDir)
                let col = j == 0 ? ramp([dark, mid, light], 0.2 + 0.8 * b) : ramp([dark, mid, light], 0.05 + 0.6 * b)
                var tri = Path()
                tri.addLines([p, side, tip])
                tri.closeSubpath()
                c.fill(tri, with: .linearGradient(Gradient(colors: [col.mix(.white, 0.15).color(), col.color()]),
                                                  startPoint: p, endPoint: tip))
            }
        }
        c.stroke(starPath(p, outer: r, inner: inner), with: .color(dark.scaled(0.8).color(0.6)),
                 style: StrokeStyle(lineWidth: 0.3, lineJoin: .round))
    }

    static func flare(_ c: inout GC, _ p: CGPoint, _ r: CGFloat, _ color: RGB, _ alpha: Double) {
        var g = c
        g.blendMode = .plusLighter
        for (dx, dy, len) in [(1.0, 0.0, r * 2.6), (0.0, 1.0, r * 1.8)] {
            let a = P(p.x - CGFloat(dx) * len, p.y - CGFloat(dy) * len)
            let b = P(p.x + CGFloat(dx) * len, p.y + CGFloat(dy) * len)
            var line = Path()
            line.move(to: a)
            line.addLine(to: b)
            g.stroke(line, with: .linearGradient(Gradient(stops: [
                .init(color: color.color(0), location: 0),
                .init(color: color.color(alpha), location: 0.5),
                .init(color: color.color(0), location: 1),
            ]), startPoint: a, endPoint: b), lineWidth: 0.35)
        }
    }
}

// MARK: - 받침

enum Bases {
    /// 타원의 세로/가로 비 — 위에서 살짝 내려다보는 시점
    static let k: CGFloat = 0.17

    static func draw(_ c: inout GC, _ style: BaseStyle) {
        switch style {
        case .skirt(let main, let trim): skirt(&c, main, trim)
        case .basket: basket(&c)
        case .brass: brass(&c)
        case .crate: crate(&c)
        case .bucket: bucket(&c)
        }
    }

    static func gradient(_ stops: [UInt32]) -> Gradient { Gradient(colors: stops.map { RGB($0).color() }) }

    /// 회전체 용기. radius(t): t = 0(위) … 1(아래)
    struct Vessel {
        var top: CGFloat
        var bottom: CGFloat
        var radius: (CGFloat) -> CGFloat

        func y(_ t: CGFloat) -> CGFloat { top + (bottom - top) * t }
        var maxR: CGFloat { (0...20).map { radius(CGFloat($0) / 20) }.max() ?? 0 }

        /// 높이 t의 앞쪽 둘레 위의 점 (u: -1 왼쪽 … 1 오른쪽)
        func point(_ t: CGFloat, _ u: CGFloat) -> CGPoint {
            let r = radius(t)
            return P(50 + r * u, y(t) + r * k * sqrt(max(0, 1 - u * u)))
        }

        func ring(_ t: CGFloat, front: Bool = true) -> Path {
            Path { p in
                for i in 0...40 {
                    let u = -1 + 2 * CGFloat(i) / 40
                    var pt = point(t, u)
                    if !front { pt.y = y(t) - radius(t) * k * sqrt(max(0, 1 - u * u)) }
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
        }

        var body: Path {
            Path { p in
                let n = 30
                for i in 0...n {
                    let t = CGFloat(i) / CGFloat(n)
                    let pt = P(50 - radius(t), y(t))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                for i in 0...40 { p.addLine(to: point(1, -1 + 2 * CGFloat(i) / 40)) }
                for i in stride(from: n, through: 0, by: -1) { p.addLine(to: P(50 + radius(CGFloat(i) / CGFloat(n)), y(CGFloat(i) / CGFloat(n)))) }
                for i in stride(from: 40, through: 0, by: -1) { p.addLine(to: point(0, -1 + 2 * CGFloat(i) / 40)) }
                p.closeSubpath()
            }
        }

        var opening: Path {
            let r = radius(0)
            return Path(ellipseIn: CGRect(x: 50 - r, y: top - r * k, width: r * 2, height: r * 2 * k))
        }

        /// 왼쪽 위 조명을 받는 둥근 몸통의 음영
        func shade(_ c: inout GC, dark: Double = 0.5) {
            var l = c
            l.clip(to: body)
            let m = maxR
            l.fill(body, with: .linearGradient(Gradient(stops: [
                .init(color: .black.opacity(dark * 0.5), location: 0),
                .init(color: .black.opacity(0), location: 0.3),
                .init(color: .black.opacity(dark * 0.35), location: 0.72),
                .init(color: .black.opacity(dark), location: 1),
            ]), startPoint: P(50 - m, 0), endPoint: P(50 + m, 0)))
        }
    }

    // MARK: 나무 줄기

    static func trunk(_ c: inout GC, bottom: CGFloat) {
        let top: CGFloat = 90
        var p = Path()
        p.move(to: P(48.5, top))
        p.addLine(to: P(51.5, top))
        p.addCurve(to: P(53.6, bottom), control1: P(51.6, bottom - 6), control2: P(52.2, bottom - 1.3))
        p.addQuadCurve(to: P(46.4, bottom), control: P(50, bottom + 0.8))
        p.addCurve(to: P(48.5, top), control1: P(47.8, bottom - 1.3), control2: P(48.4, bottom - 6))
        p.closeSubpath()
        c.fill(p, with: .linearGradient(gradient([0x22150B, 0x5E412A, 0x82614A, 0x4E3522, 0x1C1109]),
                                        startPoint: P(46.4, 0), endPoint: P(53.6, 0)))
        var bark = c
        bark.clip(to: p)
        var rng = SplitMix(state: 5)
        for i in 0..<8 {
            var line = Path()
            let x0 = 46.9 + CGFloat(i) * 0.85
            line.move(to: P(x0, top))
            var y = top
            while y < bottom + 1 {
                y += 1.2
                line.addLine(to: P(x0 + CGFloat(rng.range(-0.25, 0.25)) + (y - top) * (x0 - 50) * 0.012, y))
            }
            bark.stroke(line, with: .color(.black.opacity(0.4)), lineWidth: 0.22)
            bark.stroke(line.offsetBy(dx: 0.25, dy: 0), with: .color(RGB(0xA88468).color(0.18)), lineWidth: 0.15)
        }
        // 위쪽은 가지 그늘에 들어간다
        bark.fill(Path(CGRect(x: 40, y: top, width: 20, height: bottom - top)), with: .linearGradient(
            Gradient(colors: [.black.opacity(0.75), .black.opacity(0)]), startPoint: P(50, top), endPoint: P(50, top + 9)))
    }

    // MARK: 트리 스커트

    static func skirt(_ c: inout GC, _ main: RGB, _ trim: RGB) {
        let rect = CGRect(x: 19, y: 102, width: 62, height: 11.5)
        let e = Path(ellipseIn: rect)
        c.fill(e, with: .radialGradient(Gradient(colors: [main.scaled(1.25).color(), main.color(), main.scaled(0.45).color()]),
                                        center: P(44, 104), startRadius: 0, endRadius: 34))
        var on = c
        on.clip(to: e)
        for i in 0..<7 {
            let x = 24 + CGFloat(i) * 8.6
            Kit.softDisc(&on, P(x, 111), r: 4.2, color: main.scaled(0.35).color(), alpha: 0.35)
            Kit.softDisc(&on, P(x + 4.3, 110), r: 3.2, color: main.scaled(1.4).color(), alpha: 0.2)
        }
        // 트리가 스커트 위에 드리운 그늘과 줄기 접지
        on.fill(Path(ellipseIn: CGRect(x: 22, y: 100.5, width: 56, height: 8)), with: .radialGradient(
            Gradient(colors: [.black.opacity(0.55), .black.opacity(0)]), center: P(50, 104.5), startRadius: 0, endRadius: 28))
        on.fill(Path(ellipseIn: CGRect(x: 44.5, y: 105.4, width: 11, height: 2.6)), with: .radialGradient(
            Gradient(colors: [.black.opacity(0.6), .black.opacity(0)]), center: P(50, 106.7), startRadius: 0, endRadius: 5.5))
        var rng = SplitMix(state: 99)
        for i in 0..<120 {
            let a = Double(i) / 120 * 2 * Double.pi
            let jitter = CGFloat(rng.range(-0.4, 0.4))
            let p = P(rect.midX + (rect.width / 2 + jitter) * CGFloat(cos(a)), rect.midY + (rect.height / 2 + jitter * 0.5) * CGFloat(sin(a)))
            let lit = 0.55 + 0.45 * max(0, -cos(a + 0.6))
            let r = CGFloat(rng.range(0.9, 1.4))
            c.fill(circlePath(p, r), with: .radialGradient(
                Gradient(colors: [trim.scaled(0.75 + 0.4 * lit).color(), trim.scaled(0.6 * lit + 0.25).color(0.0)]),
                center: P(p.x - 0.3, p.y - 0.3), startRadius: 0, endRadius: r))
        }
    }

    // MARK: 라탄 바구니

    static func basket(_ c: inout GC) {
        let v = Vessel(top: 99.2, bottom: 112.8) { t in 15.2 - 3.4 * t + 0.7 * sin(t * .pi) }
        c.fill(v.opening, with: .color(RGB(0x24180E).color()))
        c.fill(v.body, with: .color(RGB(0x6A4522).color()))
        var w = c
        w.clip(to: v.body)
        let rows = 6
        for j in 0..<rows {
            let t = (CGFloat(j) + 0.55) / CGFloat(rows)
            let rowH = (v.bottom - v.top) / CGFloat(rows)
            let r = v.radius(t)
            let cols = 13
            for i in 0...cols {
                let u = -1 + 2 * (CGFloat(i) + (j.isMultiple(of: 2) ? 0 : 0.5)) / CGFloat(cols)
                guard abs(u) < 1.02 else { continue }
                let pt = v.point(t, max(-1, min(1, u)))
                let fore = sqrt(max(0.05, 1 - u * u))
                let bw = 2 * r / CGFloat(cols) * fore * 1.08
                let lit = 0.72 + 0.4 * Double(-u * 0.5 + 0.5) * Double(fore)
                let col = RGB(0xD3A46A).scaled(lit)
                let rect = CGRect(x: pt.x - bw / 2, y: pt.y - rowH * 0.5, width: bw, height: rowH * 0.92)
                w.fill(Path(roundedRect: rect, cornerRadius: min(bw, rowH) * 0.45), with: .linearGradient(
                    Gradient(colors: [col.mix(.white, 0.12).color(), col.color(), col.scaled(0.55).color()]),
                    startPoint: P(rect.midX, rect.minY), endPoint: P(rect.midX, rect.maxY)))
            }
        }
        v.shade(&c, dark: 0.55)
        // 꼰 테두리
        let rim = v.ring(0)
        c.stroke(v.ring(0, front: false), with: .color(RGB(0x7A532C).color()), lineWidth: 1.6)
        c.stroke(rim, with: .linearGradient(gradient([0x7A532C, 0xE3BC84, 0xB98A55, 0x5E3E1E]),
                                            startPoint: P(34, 0), endPoint: P(66, 0)), lineWidth: 2)
        for i in 0..<34 {
            let u = -1 + 2 * (CGFloat(i) + 0.5) / 34
            let pt = v.point(0, u)
            var twist = Path()
            twist.move(to: P(pt.x - 0.45, pt.y - 0.8))
            twist.addLine(to: P(pt.x + 0.45, pt.y + 0.8))
            c.stroke(twist, with: .color(.black.opacity(0.3)), lineWidth: 0.22)
        }
    }

    // MARK: 황동 화분

    static func brass(_ c: inout GC) {
        let body = Vessel(top: 99.6, bottom: 109.6) { t in 14.2 + 1.3 * sin(t * .pi * 0.85) - 6.8 * t * t }
        let foot = Vessel(top: 109.4, bottom: 113.4) { t in 5.6 + 2.6 * t }
        let metal = gradient([0x3E2A0C, 0x9C7424, 0xF9E6A6, 0xD6AE4A, 0x8A6420, 0x4A3410, 0x2E1F08])
        c.fill(foot.body, with: .linearGradient(metal, startPoint: P(42, 0), endPoint: P(58, 0)))
        c.fill(body.opening, with: .color(RGB(0x24180E).color()))
        c.fill(body.body, with: .linearGradient(metal, startPoint: P(50 - body.maxR, 0), endPoint: P(50 + body.maxR, 0)))
        var hl = c
        hl.clip(to: body.body)
        hl.fill(Path(CGRect(x: 41.5, y: 99, width: 2.2, height: 12)), with: .color(.white.opacity(0.28)))
        // 장식 띠
        c.stroke(body.ring(0.55), with: .color(RGB(0x5A4012).color(0.6)), lineWidth: 0.35)
        c.stroke(body.ring(0.55).offsetBy(dx: 0, dy: 0.35), with: .color(RGB(0xFFF0C0).color(0.35)), lineWidth: 0.25)
        c.stroke(body.ring(0, front: false), with: .color(RGB(0x8A6A2A).color()), lineWidth: 1.2)
        c.stroke(body.ring(0), with: .linearGradient(gradient([0x6B4E16, 0xFFF4C8, 0xC9A040, 0x5A4012]),
                                                     startPoint: P(36, 0), endPoint: P(64, 0)), lineWidth: 1.5)
    }

    // MARK: 함석 양동이

    static func bucket(_ c: inout GC) {
        let v = Vessel(top: 99.6, bottom: 113) { t in 14 - 2.8 * t }
        c.fill(v.opening, with: .color(RGB(0x22201C).color()))
        c.fill(v.body, with: .linearGradient(gradient([0x6A7278, 0xBFC8CE, 0xEEF2F4, 0xAEB7BD, 0x7E878D, 0x4E565C]),
                                             startPoint: P(50 - v.maxR, 0), endPoint: P(50 + v.maxR, 0)))
        // 아연 도금 얼룩
        var spots = c
        spots.clip(to: v.body)
        var rng = SplitMix(state: 31)
        for _ in 0..<26 {
            let p = P(CGFloat(rng.range(36, 64)), CGFloat(rng.range(100, 113)))
            Kit.softDisc(&spots, p, r: CGFloat(rng.range(1, 2.4)), color: rng.next() < 0.5 ? .white : .black, alpha: 0.08)
        }
        for t: CGFloat in [0.3, 0.68] {
            c.stroke(v.ring(t), with: .color(.black.opacity(0.28)), lineWidth: 0.5)
            c.stroke(v.ring(t).offsetBy(dx: 0, dy: 0.5), with: .color(.white.opacity(0.4)), lineWidth: 0.35)
        }
        v.shade(&c, dark: 0.35)
        // 손잡이 고정쇠
        for side: CGFloat in [-1, 1] {
            let pt = P(50 + side * (v.radius(0.12) - 0.5), v.y(0.12) + 0.2)
            c.fill(circlePath(pt, 0.75), with: .radialGradient(gradient([0xF4F7F9, 0x7E878D]), center: P(pt.x - 0.2, pt.y - 0.2),
                                                             startRadius: 0, endRadius: 0.9))
        }
        c.stroke(v.ring(0, front: false), with: .color(RGB(0x8A9298).color()), lineWidth: 1)
        c.stroke(v.ring(0), with: .linearGradient(gradient([0x737B81, 0xFAFCFD, 0xA4ADB3, 0x5E666C]),
                                                  startPoint: P(36, 0), endPoint: P(64, 0)), lineWidth: 1.3)
    }

    /// 세로축으로 phi 만큼 돌려 놓은 3D 상자. 옆면 0: -X, 1: +Z, 2: +X, 3: -Z
    struct Box3D {
        var cx: CGFloat
        var ground: CGFloat
        var a: CGFloat      // X 방향 반폭
        var b: CGFloat      // Z 방향 반폭
        var h: CGFloat
        var phi: Double
        var lift: CGFloat = 0

        var cs: CGFloat { CGFloat(cos(phi)) }
        var sn: CGFloat { CGFloat(sin(phi)) }
        var cy: CGFloat { ground - (a * abs(sn) + b * cs) * k }

        func pt(_ x3: CGFloat, _ y3: CGFloat, _ z3: CGFloat) -> CGPoint {
            let x = x3 * cs + z3 * sn, z = -x3 * sn + z3 * cs
            return P(cx + x, cy - y3 - lift + z * k)
        }

        /// u: 화면 왼→오른, v: 아래→위
        func fp(_ face: Int, _ u: CGFloat, _ v: CGFloat) -> CGPoint {
            let y = h * v
            switch face {
            case 0: return pt(-a, y, -b + 2 * b * u)
            case 1: return pt(-a + 2 * a * u, y, b)
            case 2: return pt(a, y, b - 2 * b * u)
            default: return pt(a - 2 * a * u, y, -b)
            }
        }

        func quad(_ face: Int, _ u0: CGFloat, _ u1: CGFloat, _ v0: CGFloat, _ v1: CGFloat) -> Path {
            var p = Path()
            p.addLines([fp(face, u0, v0), fp(face, u1, v0), fp(face, u1, v1), fp(face, u0, v1)])
            p.closeSubpath()
            return p
        }

        func faceLength(_ face: Int) -> CGFloat { face % 2 == 0 ? 2 * b : 2 * a }

        /// 보이는 옆면들과 밝기 (왼쪽 위 조명)
        var visibleFaces: [(face: Int, lit: Double)] {
            let normals: [(CGFloat, CGFloat)] = [(-1, 0), (0, 1), (1, 0), (0, -1)]
            return normals.enumerated().compactMap { i, n in
                let x = n.0 * cs + n.1 * sn, z = -n.0 * sn + n.1 * cs
                guard z > 0.02 else { return nil }
                return (i, Double(0.5 + 0.6 * (-0.55 * x + 0.67 * z)))
            }
        }

        /// 윗면 위의 점 (u: X 0…1, w: Z 0…1)
        func top(_ u: CGFloat, _ w: CGFloat) -> CGPoint { pt(-a + 2 * a * u, h, -b + 2 * b * w) }

        var topFace: Path {
            var p = Path()
            p.addLines([top(0, 0), top(1, 0), top(1, 1), top(0, 1)])
            p.closeSubpath()
            return p
        }
    }

    // MARK: 나무 상자 (35° 돌려 놓은 3D 상자)

    static func crate(_ c: inout GC) {
        let a: CGFloat = 11.5, h: CGFloat = 13.5
        let box = Box3D(cx: 50, ground: Kit.ground, a: a, b: a, h: h, phi: 0.6)
        let pt = box.pt, fp = box.fp, quad = box.quad

        // 윗면: 테두리와 안쪽(흙)
        let t: CGFloat = 1.3
        var rim = Path()
        rim.addLines([pt(-a, h, -a), pt(a, h, -a), pt(a, h, a), pt(-a, h, a)])
        rim.closeSubpath()
        c.fill(rim, with: .color(RGB(0xC9A06E).color()))
        var inner = Path()
        inner.addLines([pt(-a + t, h, -a + t), pt(a - t, h, -a + t), pt(a - t, h, a - t), pt(-a + t, h, a - t)])
        inner.closeSubpath()
        c.fill(inner, with: .color(RGB(0x22160C).color()))
        var backWall = Path() // 안쪽에서 보이는 뒷벽
        backWall.addLines([pt(-a + t, h, -a + t), pt(a - t, h, -a + t), pt(a - t, h - 1.6, -a + t), pt(-a + t, h - 1.6, -a + t)])
        backWall.closeSubpath()
        c.fill(backWall, with: .color(RGB(0x6E4C2C).color()))

        let tones: [RGB] = [RGB(0xB88A58), RGB(0xA97B4A), RGB(0xBE9262)]
        var rng = SplitMix(state: 17)
        for face in 0..<2 {
            let lit: Double = face == 0 ? 1.0 : 0.66
            c.fill(quad(face, 0, 1, 0, 1), with: .color(RGB(0x2E1E10).color()))
            for i in 0..<3 {
                let v0 = CGFloat(i) / 3 + 0.012, v1 = CGFloat(i + 1) / 3 - 0.012
                let tone = tones[(i + face) % 3].scaled(lit)
                c.fill(quad(face, 0, 1, v0, v1), with: .linearGradient(
                    Gradient(colors: [tone.mix(.white, 0.1).color(), tone.color(), tone.scaled(0.8).color()]),
                    startPoint: fp(face, 0.5, v1), endPoint: fp(face, 0.5, v0)))
                var grain = c
                grain.clip(to: quad(face, 0, 1, v0, v1))
                for g in 0..<3 {
                    var line = Path()
                    let gv = v0 + (v1 - v0) * (CGFloat(g) + 0.5) / 3
                    for j in 0...20 {
                        let u = CGFloat(j) / 20
                        let wob = CGFloat(sin(Double(u) * 9 + Double(g * 5 + i + face * 3))) * 0.012
                        let q = fp(face, u, gv + wob)
                        if j == 0 { line.move(to: q) } else { line.addLine(to: q) }
                    }
                    grain.stroke(line, with: .color(tone.scaled(0.6).color(0.5)), lineWidth: 0.18)
                }
                let ku = CGFloat(rng.range(0.25, 0.75))
                let kp = fp(face, ku, (v0 + v1) / 2)
                grain.fill(Path(ellipseIn: CGRect(x: kp.x - 0.8, y: kp.y - 0.4, width: 1.6, height: 0.8)),
                           with: .color(tone.scaled(0.5).color(0.7)))
                // 판자 위 모서리 하이라이트
                var edge = Path()
                edge.move(to: fp(face, 0, v1))
                edge.addLine(to: fp(face, 1, v1))
                c.stroke(edge, with: .color(.white.opacity(0.18 * lit)), lineWidth: 0.25)
            }
            // 모서리 기둥과 못
            for (u0, u1) in [(0.0, 0.1), (0.9, 1.0)] as [(CGFloat, CGFloat)] {
                let post = RGB(0x9A6E44).scaled(lit * (u0 == 0 ? 1.08 : 0.92))
                c.fill(quad(face, u0, u1, 0, 1), with: .color(post.color()))
                for i in 0..<3 {
                    let n = fp(face, (u0 + u1) / 2, (CGFloat(i) + 0.5) / 3)
                    c.fill(circlePath(n, 0.28), with: .color(RGB(0x2A2622).color()))
                    c.fill(circlePath(P(n.x - 0.08, n.y - 0.08), 0.1), with: .color(.white.opacity(0.4)))
                }
            }
            // 위쪽은 트리 그늘
            var ao = c
            ao.clip(to: quad(face, 0, 1, 0, 1))
            ao.fill(quad(face, 0, 1, 0.55, 1), with: .linearGradient(
                Gradient(colors: [.black.opacity(0), .black.opacity(0.4)]),
                startPoint: fp(face, 0.5, 0.55), endPoint: fp(face, 0.5, 1)))
        }
        // 앞 모서리 강조
        var corner = Path()
        corner.move(to: pt(-a, 0, a))
        corner.addLine(to: pt(-a, h, a))
        c.stroke(corner, with: .color(RGB(0xE0BC8C).color(0.5)), lineWidth: 0.3)
    }
}

// MARK: - 선물 상자

enum Gifts {
    static func draw(_ c: inout GC) {
        box(&c, Bases.Box3D(cx: 70, ground: Kit.ground - 0.2, a: 7.5, b: 6, h: 10, phi: -0.5), RGB(0x1D4E89), ribbon: RGB(0xE8E8EA))
        box(&c, Bases.Box3D(cx: 29, ground: Kit.ground - 0.2, a: 9, b: 7.5, h: 13, phi: 0.42), RGB(0x9E1B24), ribbon: RGB(0xE7C46C))
        box(&c, Bases.Box3D(cx: 49, ground: Kit.ground, a: 6.5, b: 5.5, h: 7.5, phi: 0.2), RGB(0xF2EEE6), ribbon: RGB(0x9E1B24))
    }

    static func box(_ c: inout GC, _ body: Bases.Box3D, _ color: RGB, ribbon: RGB) {
        let lidH: CGFloat = min(2.6, body.h * 0.22)
        var lid = body
        lid.a += 0.45; lid.b += 0.45
        lid.h = lidH
        lid.lift = body.h - lidH
        lid.ground = body.ground + (lid.a * abs(lid.sn) + lid.b * lid.cs - body.a * abs(body.sn) - body.b * body.cs) * Bases.k

        let rw: CGFloat = 1.3
        func band(_ box: Bases.Box3D, _ face: Int) -> Path {
            let half = rw / 2 / box.faceLength(face)
            return box.quad(face, 0.5 - half, 0.5 + half, 0, 1)
        }
        // 몸통 옆면
        for (face, lit) in body.visibleFaces {
            let col = color.scaled(0.55 + 0.55 * lit)
            c.fill(body.quad(face, 0, 1, 0, 1), with: .linearGradient(
                Gradient(colors: [col.color(), col.scaled(0.82).color()]),
                startPoint: body.fp(face, 0.5, 1), endPoint: body.fp(face, 0.5, 0)))
            c.fill(band(body, face), with: .color(ribbon.scaled(0.6 + 0.5 * lit).color()))
        }
        // 뚜껑
        for (face, lit) in lid.visibleFaces {
            let col = color.scaled(0.6 + 0.6 * lit)
            c.fill(lid.quad(face, 0, 1, 0, 1), with: .color(col.color()))
            c.fill(band(lid, face), with: .color(ribbon.scaled(0.65 + 0.5 * lit).color()))
            var edge = Path()
            edge.move(to: lid.fp(face, 0, 0))
            edge.addLine(to: lid.fp(face, 1, 0))
            c.stroke(edge, with: .color(.black.opacity(0.3)), lineWidth: 0.3)
        }
        c.fill(lid.topFace, with: .color(color.mix(.white, 0.16).color()))
        // 윗면 리본 십자
        let half = rw / 2
        var r1 = Path()
        r1.addLines([lid.top(0.5 - half / (2 * lid.a), 0), lid.top(0.5 + half / (2 * lid.a), 0),
                     lid.top(0.5 + half / (2 * lid.a), 1), lid.top(0.5 - half / (2 * lid.a), 1)])
        r1.closeSubpath()
        var r2 = Path()
        r2.addLines([lid.top(0, 0.5 - half / (2 * lid.b)), lid.top(1, 0.5 - half / (2 * lid.b)),
                     lid.top(1, 0.5 + half / (2 * lid.b)), lid.top(0, 0.5 + half / (2 * lid.b))])
        r2.closeSubpath()
        c.fill(r1, with: .color(ribbon.mix(.white, 0.2).color()))
        c.fill(r2, with: .color(ribbon.mix(.white, 0.2).color()))
        bow(&c, lid.top(0.5, 0.5), size: min(body.a, body.b) * 0.42, ribbon)
    }

    static func bow(_ c: inout GC, _ k: CGPoint, size: CGFloat, _ ribbon: RGB) {
        let dark = ribbon.scaled(0.6).color()
        for side: CGFloat in [-1, 1] {
            var tail = Path()
            tail.addLines([k, P(k.x + side * size * 0.9, k.y + size * 1.2), P(k.x + side * size * 0.45, k.y + size * 1.35)])
            tail.closeSubpath()
            c.fill(tail, with: .color(dark))
            var loop = Path()
            loop.move(to: k)
            loop.addCurve(to: k, control1: P(k.x + side * size * 1.7, k.y - size * 1.5),
                          control2: P(k.x + side * size * 2.0, k.y + size * 0.35))
            c.fill(loop, with: .linearGradient(Gradient(colors: [ribbon.mix(.white, 0.35).color(), dark]),
                                               startPoint: P(k.x, k.y - size), endPoint: P(k.x + side * size * 1.8, k.y + size * 0.4)))
            var inner = Path()
            inner.move(to: P(k.x + side * size * 0.3, k.y - size * 0.1))
            inner.addQuadCurve(to: P(k.x + side * size * 1.2, k.y - size * 0.25), control: P(k.x + side * size * 0.8, k.y - size * 0.75))
            c.stroke(inner, with: .color(ribbon.scaled(0.45).color(0.6)), lineWidth: 0.3)
        }
        c.fill(Path(ellipseIn: CGRect(x: k.x - size * 0.4, y: k.y - size * 0.35, width: size * 0.8, height: size * 0.7)),
               with: .color(ribbon.scaled(0.85).color()))
    }
}

// MARK: - 캐시

/// 잎/장식처럼 움직이지 않는 부분을 이미지로 한 번만 그려 두고 재사용한다
@MainActor
final class TreeLayerCache {
    static let shared = TreeLayerCache()

    private struct ModelKey: Hashable { let design: TreeDesign; let lod: Int }
    private struct ImageKey: Hashable { let design: TreeDesign; let w: Int; let h: Int }

    private var models: [ModelKey: TreeModel] = [:]
    private var images: [ImageKey: CGImage] = [:]
    private var order: [ImageKey] = []

    func model(_ d: TreeDesign, pixelWidth: CGFloat) -> TreeModel {
        let lod = pixelWidth < 120 ? 1 : (pixelWidth < 300 ? 2 : 3)
        let key = ModelKey(design: d, lod: lod)
        if let m = models[key] { return m }
        let m = TreeModel(recipe: d.recipe, lod: [0, 0.3, 0.65, 1][lod])
        models[key] = m
        return m
    }

    /// 100×125 디자인 영역을 `pixelSize` 크기의 이미지로
    func image(_ d: TreeDesign, pixelSize: CGSize) -> CGImage? {
        let key = ImageKey(design: d, w: Int(pixelSize.width.rounded()), h: Int(pixelSize.height.rounded()))
        if let img = images[key] { return img }
        let m = model(d, pixelWidth: pixelSize.width)
        let view = Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 100, y: size.height / 125)
            m.drawStatic(&ctx)
        }
        .frame(width: CGFloat(key.w), height: CGFloat(key.h))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let img = renderer.cgImage else { return nil }
        images[key] = img
        order.append(key)
        if order.count > 10 { images[order.removeFirst()] = nil }
        return img
    }
}
