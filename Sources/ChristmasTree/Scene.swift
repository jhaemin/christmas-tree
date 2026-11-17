import SwiftUI

/// 눈송이 — 상태 없이 시간만으로 위치를 계산한다
enum Snow {
    struct Flake {
        let x, offset, speed, size, amp, freq, phase: Double
        let front: Bool
    }

    static let flakes: [Flake] = {
        var r = SplitMix(state: 2024)
        return (0..<500).map { _ in
            Flake(x: r.next(), offset: r.next(), speed: r.range(10, 24), size: r.range(0.6, 1.8),
                  amp: r.range(3, 10), freq: r.range(0.4, 1.3), phase: r.range(0, 6.3), front: r.next() < 0.45)
        }
    }()

    static func draw(_ c: inout GC, size: CGSize, t: Double, front: Bool, alpha: Double) {
        guard alpha > 0.01 else { return }
        let scale = size.width / 180
        // 눈송이 크기가 scale에 비례하므로, 개수는 scale² 로 나눠 어떤 크기에서도 밀도가 같게 한다
        let count = min(flakes.count, Int(size.width * size.height / (560 * scale * scale)))
        let h = Double(size.height) + 12
        for i in 0..<count {
            let f = flakes[i]
            guard f.front == front else { continue }
            let speed = f.speed * Double(scale) * (0.7 + 0.3 * f.size / 1.8)
            let y = (t * speed + f.offset * h).truncatingRemainder(dividingBy: h) - 6
            let x = f.x * Double(size.width) + sin(t * f.freq + f.phase) * f.amp * Double(scale)
            let r = CGFloat(f.size) * scale * (front ? 1.1 : 0.75)
            let p = P(CGFloat(x), CGFloat(y))
            let a = (front ? 0.95 : 0.7) * alpha
            c.fill(circlePath(p, r * 1.7), with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(a), location: 0),
                    .init(color: .white.opacity(a * 0.75), location: 0.45),
                    .init(color: .white.opacity(0), location: 1),
                ]),
                center: p, startRadius: 0, endRadius: r * 1.7))
        }
    }
}

/// 한 프레임을 그리는 데 필요한 상태 스냅샷
struct SceneSnapshot {
    var design: TreeDesign
    var previousDesign: TreeDesign?
    var designChangedAt: Double
    var snow: Bool
    var snowChangedAt: Double
}

/// 트리 한 그루를 그리는 데 필요한 것: 정적 이미지 + 동적 요소를 그릴 모델
struct TreeLayer {
    let model: TreeModel
    let image: CGImage?

    @MainActor
    static func make(_ d: TreeDesign, viewSize: CGSize, scale: CGFloat) -> TreeLayer {
        let rect = SceneRenderer.designRect(in: viewSize)
        let px = CGSize(width: rect.width * scale, height: rect.height * scale)
        let cache = TreeLayerCache.shared
        return TreeLayer(model: cache.model(d, pixelWidth: px.width), image: cache.image(d, pixelSize: px))
    }

    func draw(_ c: inout GC, _ t: Double) {
        if let image {
            c.draw(Image(decorative: image, scale: 1), in: CGRect(x: 0, y: 0, width: 100, height: 125))
        }
        model.drawDynamic(&c, t)
    }
}

enum SceneRenderer {
    static let designSize = CGSize(width: 100, height: 125)

    /// 별빛이 창 위쪽에서 잘리지 않도록 디자인 영역 위에 두는 여백 (디자인 단위)
    static let topPadding: CGFloat = 10

    static func designRect(in size: CGSize) -> CGRect {
        let total = designSize.height + topPadding
        let k = min(size.width / designSize.width, size.height / total)
        return CGRect(x: (size.width - designSize.width * k) / 2,
                      y: (size.height - total * k) / 2 + topPadding * k,
                      width: designSize.width * k, height: designSize.height * k)
    }

    static func draw(_ ctx: inout GC, size: CGSize, t: Double, scene s: SceneSnapshot,
                     current: TreeLayer, previous: TreeLayer?) {
        let sinceSnow = t - s.snowChangedAt
        let snowAlpha = s.snow ? min(1, sinceSnow / 0.8) : max(0, 1 - sinceSnow / 0.8)

        Snow.draw(&ctx, size: size, t: t, front: false, alpha: snowAlpha)

        var d = ctx
        let rect = designRect(in: size)
        d.translateBy(x: rect.minX, y: rect.minY)
        d.scaleBy(x: rect.width / designSize.width, y: rect.height / designSize.height)

        let p = min(1, max(0, (t - s.designChangedAt) / 0.5))
        if let previous, p < 1 {
            var old = d
            old.opacity = 1 - p
            old.drawLayer { layer in previous.draw(&layer, t) }
            var new = d
            new.opacity = p
            new.drawLayer { layer in current.draw(&layer, t) }
        } else {
            current.draw(&d, t)
        }

        Snow.draw(&ctx, size: size, t: t, front: true, alpha: snowAlpha)
    }
}

/// 메뉴 썸네일·미리보기용 정지 이미지
struct DesignStill: View {
    let design: TreeDesign
    let size: CGSize
    var scale: CGFloat = 2
    var t: Double = 1.3
    var snow = false

    var body: some View {
        let layer = TreeLayer.make(design, viewSize: size, scale: scale)
        let snapshot = SceneSnapshot(design: design, previousDesign: nil, designChangedAt: -100,
                                     snow: snow, snowChangedAt: -100)
        return Canvas { ctx, sz in
            SceneRenderer.draw(&ctx, size: sz, t: t, scene: snapshot, current: layer, previous: nil)
        }
        .frame(width: size.width, height: size.height)
    }
}
