import SwiftUI

enum TreeDesign: Int, CaseIterable, Identifiable {
    case classic, snowy, champagne, burgundy, silverBlue, flocked, nordic
    case warmGlow, vintage, emerald, gifts, spruce, spiral, wire

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .classic: L("Classic Red & Gold")
        case .snowy: L("Snowy Fir")
        case .champagne: L("Champagne Gold")
        case .burgundy: L("Burgundy Velvet")
        case .silverBlue: L("Silver & Blue")
        case .flocked: L("White Flocked")
        case .nordic: L("Nordic Wood")
        case .warmGlow: L("Warm Glow")
        case .vintage: L("Vintage Bulbs")
        case .emerald: L("Emerald & Gold")
        case .gifts: L("Gifts Galore")
        case .spruce: L("Blue Spruce")
        case .spiral: L("Spiral Lights")
        case .wire: L("Gold Wire")
        }
    }

    var recipe: TreeRecipe {
        let gold = RGB(0xD4A63A), red = RGB(0xA3121C), ivory = RGB(0xEFE6D2)
        var r = TreeRecipe(seed: UInt64(rawValue + 1))
        switch self {
        case .classic:
            r.ornaments = [OrnamentKind(color: red, finish: .glossy), OrnamentKind(color: gold, finish: .glossy),
                           OrnamentKind(color: RGB(0x7E0F16), finish: .matte), OrnamentKind(color: gold, finish: .glitter, size: 0.85)]
            r.ornamentCount = 26
            r.beads = RGB(0xF3D58A)
            r.base = .skirt(RGB(0x8E1520), trim: RGB(0xF4EFE6))
        case .snowy:
            r.foliage = .deepFir
            r.foliage.snow = 0.85
            r.ornaments = [OrnamentKind(color: RGB(0xDCE3EA), finish: .glossy, size: 0.9),
                           OrnamentKind(color: RGB(0xB9C6D2), finish: .glitter, size: 0.8)]
            r.ornamentCount = 12
            r.lights = .mixed
            r.lightCount = 70
            r.star = .silver
            r.base = .bucket
        case .champagne:
            r.ornaments = [OrnamentKind(color: RGB(0xE3C27A), finish: .glossy), OrnamentKind(color: ivory, finish: .matte),
                           OrnamentKind(color: RGB(0xC9A15A), finish: .glitter), OrnamentKind(color: RGB(0xF2DCA6), finish: .glossy, drop: true)]
            r.ornamentCount = 28
            r.ribbon = RibbonStyle(dark: RGB(0x7A5A22), mid: RGB(0xC9A452), light: RGB(0xF8E7B5), width: 3.2)
            r.base = .basket
        case .burgundy:
            r.foliage = .deepFir
            r.ornaments = [OrnamentKind(color: RGB(0x6E0F22), finish: .glossy), OrnamentKind(color: RGB(0x8A1A30), finish: .matte),
                           OrnamentKind(color: gold, finish: .glossy, size: 0.85), OrnamentKind(color: RGB(0x5A0C1C), finish: .glitter, drop: true)]
            r.ornamentCount = 26
            r.ribbon = RibbonStyle(dark: RGB(0x2E0610), mid: RGB(0x6E1024), light: RGB(0xB2384F), width: 3.4)
            r.base = .brass
        case .silverBlue:
            r.foliage = .deepFir
            r.ornaments = [OrnamentKind(color: RGB(0x1F4FA8), finish: .glossy), OrnamentKind(color: RGB(0xC9D2DA), finish: .glossy),
                           OrnamentKind(color: RGB(0x0E2A66), finish: .matte), OrnamentKind(color: RGB(0x9FB4CC), finish: .glitter, drop: true)]
            r.ornamentCount = 26
            r.ribbon = RibbonStyle(dark: RGB(0x5C6670), mid: RGB(0xAEB8C2), light: RGB(0xF5F8FA), width: 2.8)
            r.lights = .cool
            r.star = .silver
            r.base = .skirt(RGB(0xE9ECEF), trim: RGB(0xB9C2CB))
        case .flocked:
            r.foliage = .fir
            r.foliage.flock = 0.85
            r.ornaments = [OrnamentKind(color: RGB(0xE7B4A6), finish: .glossy), OrnamentKind(color: RGB(0xD49A88), finish: .glitter),
                           OrnamentKind(color: RGB(0xF4E4DC), finish: .matte), OrnamentKind(color: RGB(0xC98E7A), finish: .glossy, drop: true)]
            r.ornamentCount = 24
            r.star = .roseGold
            r.base = .bucket
        case .nordic:
            r.foliage.density = 0.8
            r.ornaments = [OrnamentKind(color: RGB(0xB3261E), finish: .matte), OrnamentKind(color: RGB(0xF1EBDD), finish: .matte),
                           OrnamentKind(color: RGB(0xA77B4F), finish: .matte, size: 0.9)]
            r.ornamentCount = 16
            r.lightCount = 50
            r.star = .straw
            r.base = .crate
        case .warmGlow:
            r.foliage = .deepFir
            r.lightCount = 170
            r.star = .glow
            r.base = .basket
        case .vintage:
            r.ornaments = [OrnamentKind(color: RGB(0xC9D3DA), finish: .glossy, size: 0.85),
                           OrnamentKind(color: RGB(0x3E8E6E), finish: .glossy, size: 0.85)]
            r.ornamentCount = 10
            r.lights = .vintage
            r.lightCount = 46
            r.base = .crate
        case .emerald:
            r.foliage = .deepFir
            r.ornaments = [OrnamentKind(color: RGB(0x0F6B4A), finish: .glossy), OrnamentKind(color: gold, finish: .glossy),
                           OrnamentKind(color: RGB(0x0A4D35), finish: .glitter), OrnamentKind(color: RGB(0xE8C670), finish: .matte, drop: true)]
            r.ornamentCount = 26
            r.beads = RGB(0xF3D58A)
            r.base = .brass
        case .gifts:
            r.ornaments = [OrnamentKind(color: red, finish: .glossy), OrnamentKind(color: gold, finish: .glossy),
                           OrnamentKind(color: RGB(0x1D4E89), finish: .glossy)]
            r.ornamentCount = 22
            r.ribbon = RibbonStyle(dark: RGB(0x4A060C), mid: RGB(0x9E1B24), light: RGB(0xE0505A), width: 2.6)
            r.base = .skirt(RGB(0x8E1520), trim: RGB(0xF4EFE6))
            r.gifts = true
        case .spruce:
            r.foliage = .spruce
            r.foliage.snow = 0.3
            r.ornaments = [OrnamentKind(color: RGB(0xF4F6F8), finish: .glossy), OrnamentKind(color: RGB(0x9DB4C8), finish: .glitter),
                           OrnamentKind(color: RGB(0xC7D6E2), finish: .matte, drop: true)]
            r.ornamentCount = 20
            r.lights = .cool
            r.star = .silver
            r.base = .bucket
        case .spiral:
            r.foliage = .deepFir
            r.ornaments = [OrnamentKind(color: gold, finish: .glossy, size: 0.8)]
            r.ornamentCount = 10
            r.lights = .rotating
            r.lightCount = 110
            r.base = .basket
        case .wire:
            r.wire = true
            r.lightCount = 130
            r.star = .glow
        }
        return r
    }
}
