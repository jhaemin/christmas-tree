#!/usr/bin/env swift
// Generates the Icon Composer document (Assets/AppIcon.icon: layer PNGs +
// icon.json) and a still of the icon as macOS renders it
// (Assets/icon-1024.png), so the artwork is reproducible from source.
// The .icns the app ships is actool's render of the same document
// (Scripts/bundle.sh).
// Run: swift Scripts/make-assets.swift

import AppKit

// MARK: - Helpers

func makeBitmap(_ w: Int, _ h: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
}

/// Draws into a 1024x1024 bitmap with a TOP-LEFT origin (y grows downward),
/// which is how the geometry below is written.
/// `scale` enlarges the drawing about `pivot`.
func makeLayer(scale: CGFloat = 1, pivot: CGPoint = CGPoint(x: 512, y: 512),
               _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = makeBitmap(1024, 1024)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.translateBy(x: 0, y: 1024)
    cg.scaleBy(x: 1, y: -1)
    cg.translateBy(x: pivot.x, y: pivot.y)
    cg.scaleBy(x: scale, y: scale)
    cg.translateBy(x: -pivot.x, y: -pivot.y)
    draw(cg)
    NSGraphicsContext.current = nil
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, _ path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let rgb = CGColorSpaceCreateDeviceRGB()

func fillGradient(_ cg: CGContext, _ path: CGPath, _ colors: [UInt32], from: CGPoint, to: CGPoint,
                  locations: [CGFloat]? = nil) {
    cg.saveGState()
    cg.addPath(path)
    cg.clip()
    let grad = CGGradient(colorsSpace: rgb, colors: colors.map { color($0) } as CFArray,
                          locations: locations)!
    cg.drawLinearGradient(grad, start: from, end: to,
                          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    cg.restoreGState()
}

/// A polygon with every corner rounded (arc-tangent joins).
func roundedPolygon(_ pts: [CGPoint], radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let n = pts.count
    let start = CGPoint(x: (pts[n - 1].x + pts[0].x) / 2, y: (pts[n - 1].y + pts[0].y) / 2)
    path.move(to: start)
    for i in 0..<n {
        path.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % n], radius: radius)
    }
    path.closeSubpath()
    return path
}

func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
}

// MARK: - Design (1024pt canvas = the whole icon shape; top-left origin)

/* A night-blue ground and, on it, a stylized Christmas tree built from
   materials the system can light as Liquid Glass:
     - three stacked tiers, each a rounded triangle lit pale mint at its tip
       and sinking to deep pine at its hem, so the tiers read apart;
     - a short trunk under them;
     - glossy baubles (red, gold, ivory) hung on the tiers;
     - a gold star sitting on the top tier's tip;
     - a few snowflakes drifting behind, as frosted glass.
   Each material is its own group, so the system gives each its own glass
   edge, specular highlight and shadow. */

let groundTop: UInt32 = 0x2B4C8C     // L≈33
let groundBottom: UInt32 = 0x0E1C42  // L≈12

struct Tier { let apexY, baseY, halfWidth: CGFloat }
let tiers = [
    Tier(apexY: 250, baseY: 470, halfWidth: 158),
    Tier(apexY: 360, baseY: 630, halfWidth: 236),
    Tier(apexY: 480, baseY: 800, halfWidth: 312),
]
let cx: CGFloat = 512

func tierPath(_ t: Tier) -> CGPath {
    // The hem bows slightly downward in the middle, like a skirt of
    // branches seen from a little above.
    let path = CGMutablePath()
    let r: CGFloat = 46
    let apex = CGPoint(x: cx, y: t.apexY)
    let left = CGPoint(x: cx - t.halfWidth, y: t.baseY)
    let right = CGPoint(x: cx + t.halfWidth, y: t.baseY)
    let hemMid = CGPoint(x: cx, y: t.baseY + 26)
    path.move(to: CGPoint(x: (apex.x + left.x) / 2, y: (apex.y + left.y) / 2))
    path.addArc(tangent1End: apex, tangent2End: right, radius: r * 0.8)
    path.addArc(tangent1End: right, tangent2End: hemMid, radius: r)
    path.addQuadCurve(to: CGPoint(x: cx - t.halfWidth + r * 1.2, y: t.baseY + 6),
                      control: CGPoint(x: cx, y: t.baseY + 40))
    path.addArc(tangent1End: left, tangent2End: apex, radius: r)
    path.closeSubpath()
    return path
}

let trunk = CGPath(roundedRect: CGRect(x: cx - 52, y: 770, width: 104, height: 112),
                   cornerWidth: 26, cornerHeight: 26, transform: nil)

let starCenter = CGPoint(x: cx, y: 222)
func starPath(_ c: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
    var pts: [CGPoint] = []
    for i in 0..<10 {
        let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let r = i.isMultiple(of: 2) ? outer : inner
        pts.append(CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
    }
    return roundedPolygon(pts, radius: 14)
}

let baubles: [(CGPoint, CGFloat, [UInt32])] = {
    let red: [UInt32] = [0xFF8A8A, 0xE0303C, 0xA3121C]
    let gold: [UInt32] = [0xFFF0B0, 0xF5C04A, 0xC98A1A]
    let ivory: [UInt32] = [0xFFFFFF, 0xF4EEE2, 0xCFC6B4]
    return [
        (CGPoint(x: 452, y: 418), 30, red),
        (CGPoint(x: 580, y: 400), 24, gold),
        (CGPoint(x: 400, y: 582), 32, gold),
        (CGPoint(x: 520, y: 540), 22, ivory),
        (CGPoint(x: 640, y: 590), 30, red),
        (CGPoint(x: 330, y: 752), 30, red),
        (CGPoint(x: 470, y: 720), 26, ivory),
        (CGPoint(x: 600, y: 742), 34, gold),
        (CGPoint(x: 724, y: 748), 24, ivory),
    ]
}()

let flakes: [(CGPoint, CGFloat)] = [
    (CGPoint(x: 196, y: 238), 16), (CGPoint(x: 300, y: 150), 10), (CGPoint(x: 156, y: 420), 11),
    (CGPoint(x: 820, y: 210), 14), (CGPoint(x: 724, y: 128), 9), (CGPoint(x: 872, y: 398), 12),
    (CGPoint(x: 236, y: 560), 9), (CGPoint(x: 800, y: 520), 8), (CGPoint(x: 120, y: 640), 13),
    (CGPoint(x: 904, y: 660), 11),
]

// MARK: Layers

func layerStar(_ cg: CGContext) {
    let star = starPath(starCenter, outer: 96, inner: 42)
    fillGradient(cg, star, [0xFFF4C2, 0xFFD45C, 0xE9A23B],
                 from: CGPoint(x: cx, y: starCenter.y - 96), to: CGPoint(x: cx, y: starCenter.y + 80))
}

func layerBaubles(_ cg: CGContext) {
    for (c, r, cols) in baubles {
        // Lit from the upper left: pale highlight → body → shade
        cg.saveGState()
        cg.addPath(circle(c, r))
        cg.clip()
        let grad = CGGradient(colorsSpace: rgb, colors: cols.map { color($0) } as CFArray,
                              locations: [0, 0.45, 1])!
        cg.drawRadialGradient(grad, startCenter: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0,
                              endCenter: c, endRadius: r * 1.1, options: [.drawsAfterEndLocation])
        cg.restoreGState()
    }
}

func layerTiers(_ cg: CGContext) {
    // Bottom tier first so the upper ones overlap it
    for t in tiers.reversed() {
        fillGradient(cg, tierPath(t), [0x9BE8B0, 0x2FA35E, 0x0F5A34],
                     from: CGPoint(x: cx, y: t.apexY), to: CGPoint(x: cx, y: t.baseY + 20),
                     locations: [0, 0.5, 1])
    }
}

func layerTrunk(_ cg: CGContext) {
    fillGradient(cg, trunk, [0xB0754A, 0x6B3F22],
                 from: CGPoint(x: cx, y: 770), to: CGPoint(x: cx, y: 882))
}

func layerSnow(_ cg: CGContext) {
    cg.setFillColor(color(0xFFFFFF))
    for (c, r) in flakes { cg.addPath(circle(c, r)) }
    cg.fillPath()
}

// MARK: - Icon Composer document

struct Layer {
    let name: String
    let draw: (CGContext) -> Void
    var scale: CGFloat = glyphScale
}

/// The tree's pieces are drawn a little larger than authored above, about
/// the middle of the tree, so the glyph fills ~60% of the icon's width.
let glyphScale: CGFloat = 1.12
let glyphPivot = CGPoint(x: 512, y: 536)
struct Group {
    let layers: [Layer]          // first = topmost
    var translucent = false      // frosted: the ground shows through
}

/// First group is drawn on top.
let groups: [Group] = [
    Group(layers: [Layer(name: "star", draw: layerStar)]),
    Group(layers: [Layer(name: "baubles", draw: layerBaubles)]),
    Group(layers: [Layer(name: "tiers", draw: layerTiers), Layer(name: "trunk", draw: layerTrunk)]),
    Group(layers: [Layer(name: "snow", draw: layerSnow, scale: 1)], translucent: true),
]

let fm = FileManager.default
try? fm.removeItem(atPath: "Assets/AppIcon.icon")
try! fm.createDirectory(atPath: "Assets/AppIcon.icon/Assets", withIntermediateDirectories: true)
for group in groups {
    for layer in group.layers {
        savePNG(makeLayer(scale: layer.scale, pivot: glyphPivot, layer.draw), "Assets/AppIcon.icon/Assets/\(layer.name).png")
    }
}

func srgb(_ hex: UInt32) -> String {
    let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
    return String(format: "extended-srgb:%.5f,%.5f,%.5f,1.00000", r, g, b)
}

func groupJSON(_ g: Group) -> [String: Any] {
    var dict: [String: Any] = [
        "layers": g.layers.map { ["glass": true, "image-name": "\($0.name).png", "name": $0.name] },
        "shadow": ["kind": "neutral", "opacity": 0.5],
        "specular": true,
    ]
    if g.translucent {
        dict["translucency"] = ["enabled": true, "value": 0.5]
        dict["blur-material"] = 0.5
    }
    return dict
}

/* Background: a two-stop linear gradient. A single-color automatic
   gradient renders almost flat in the Dock. */
let document: [String: Any] = [
    "fill": ["linear-gradient": [srgb(groundTop), srgb(groundBottom)]],
    "groups": groups.map(groupJSON),
    "supported-platforms": ["circles": ["watchOS"], "squares": "shared"],
]
let json = try! JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "Assets/AppIcon.icon/icon.json"))
print("wrote Assets/AppIcon.icon/icon.json (\(groups.count) groups)")

// MARK: - The icon as macOS renders it

/* Compiles the document with actool into a throwaway stub bundle (unique
   path and bundle ID per run, so Launch Services never hands back a cached
   icon) and lets NSWorkspace render it — the same Liquid Glass rendering
   the Dock and Finder show. */
func systemRenderedIcon(px: Int) -> NSBitmapImageRep? {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("christmas-tree-icon-\(ProcessInfo.processInfo.processIdentifier)")
    defer { try? fm.removeItem(at: root) }
    let compiled = root.appendingPathComponent("compiled")
    let stub = root.appendingPathComponent("ChristmasTree-icon-preview-\(UUID().uuidString.prefix(8)).app")
    let resources = stub.appendingPathComponent("Contents/Resources")
    let executables = stub.appendingPathComponent("Contents/MacOS")
    for dir in [compiled, resources, executables] {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    let actool = Process()
    actool.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    actool.arguments = [
        "actool", fm.currentDirectoryPath + "/Assets/AppIcon.icon",  // absolute: ibtoold caches by path
        "--compile", compiled.path, "--app-icon", "AppIcon",
        "--output-partial-info-plist", compiled.appendingPathComponent("partial.plist").path,
        "--platform", "macosx", "--minimum-deployment-target", "26.0",
    ]
    actool.standardOutput = FileHandle.nullDevice
    actool.standardError = FileHandle.nullDevice
    guard (try? actool.run()) != nil else { return nil }
    actool.waitUntilExit()
    guard actool.terminationStatus == 0,
          (try? fm.copyItem(at: compiled.appendingPathComponent("Assets.car"),
                            to: resources.appendingPathComponent("Assets.car"))) != nil
    else { return nil }
    try? fm.copyItem(at: compiled.appendingPathComponent("AppIcon.icns"),
                     to: resources.appendingPathComponent("AppIcon.icns"))

    let info: [String: Any] = [
        "CFBundleIdentifier": "com.jhaemin.christmas-tree.icon-preview.\(UUID().uuidString.prefix(8))",
        "CFBundleName": "ChristmasTree", "CFBundlePackageType": "APPL", "CFBundleExecutable": "stub",
        "CFBundleIconName": "AppIcon", "CFBundleIconFile": "AppIcon",
    ]
    let stubExecutable = executables.appendingPathComponent("stub")
    guard let plist = try? PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0),
          (try? plist.write(to: stub.appendingPathComponent("Contents/Info.plist"))) != nil,
          (try? "#!/bin/sh\n".write(to: stubExecutable, atomically: true, encoding: .utf8)) != nil
    else { return nil }
    try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stubExecutable.path)

    let icon = NSWorkspace.shared.icon(forFile: stub.path)
    let rep = makeBitmap(px, px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

if let rendered = systemRenderedIcon(px: 1024) {
    savePNG(rendered, "Assets/icon-1024.png")
} else {
    print("warning: actool unavailable — Assets/icon-1024.png not updated")
}
