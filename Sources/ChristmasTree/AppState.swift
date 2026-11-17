import AppKit
import Combine

enum TreeSize: Int, CaseIterable {
    case small, medium, large, huge

    var name: String {
        switch self {
        case .small: L("Small")
        case .medium: L("Medium")
        case .large: L("Large")
        case .huge: L("Extra Large")
        }
    }

    var cgSize: CGSize {
        switch self {
        case .small: CGSize(width: 120, height: 150)
        case .medium: CGSize(width: 180, height: 225)
        case .large: CGSize(width: 260, height: 325)
        case .huge: CGSize(width: 360, height: 450)
        }
    }
}

enum Volume: Int, CaseIterable {
    case low, medium, high

    var name: String {
        switch self {
        case .low: L("Quiet")
        case .medium: L("Normal")
        case .high: L("Loud")
        }
    }

    var gain: Float {
        switch self {
        case .low: 0.25
        case .medium: 0.55
        case .high: 1.0
        }
    }
}

final class AppState: ObservableObject {
    static let shared = AppState()

    private enum Key {
        static let design = "design", snow = "snow", music = "music", song = "song"
        static let volume = "volume", size = "size", onTop = "alwaysOnTop", hintShown = "hintShown"
    }

    private let defaults = UserDefaults.standard

    @Published private(set) var design: TreeDesign
    private(set) var previousDesign: TreeDesign?
    private(set) var designChangedAt: Double = -100

    @Published var snowEnabled: Bool {
        didSet { snowChangedAt = AppClock.now; defaults.set(snowEnabled, forKey: Key.snow) }
    }
    private(set) var snowChangedAt: Double = -100

    @Published var musicEnabled: Bool { didSet { defaults.set(musicEnabled, forKey: Key.music) } }
    /// -1 = 전체 연속 재생
    @Published var song: Int { didSet { defaults.set(song, forKey: Key.song) } }
    @Published var volume: Volume { didSet { defaults.set(volume.rawValue, forKey: Key.volume) } }
    @Published var size: TreeSize { didSet { defaults.set(size.rawValue, forKey: Key.size) } }
    @Published var alwaysOnTop: Bool { didSet { defaults.set(alwaysOnTop, forKey: Key.onTop) } }
    @Published var showHint = false
    /// 창이 가려지거나 화면이 잠기면 애니메이션을 멈춰 CPU를 아낀다
    @Published var isVisible = true

    private init() {
        defaults.register(defaults: [
            Key.design: TreeDesign.classic.rawValue, Key.snow: true, Key.music: false, Key.song: -1,
            Key.volume: Volume.medium.rawValue, Key.size: TreeSize.medium.rawValue, Key.onTop: true,
        ])
        design = TreeDesign(rawValue: defaults.integer(forKey: Key.design)) ?? .classic
        snowEnabled = defaults.bool(forKey: Key.snow)
        musicEnabled = defaults.bool(forKey: Key.music)
        let savedSong = defaults.integer(forKey: Key.song)
        song = (-1..<Songs.all.count).contains(savedSong) ? savedSong : -1
        volume = Volume(rawValue: defaults.integer(forKey: Key.volume)) ?? .medium
        size = TreeSize(rawValue: defaults.integer(forKey: Key.size)) ?? .medium
        alwaysOnTop = defaults.bool(forKey: Key.onTop)
    }

    var snapshot: SceneSnapshot {
        SceneSnapshot(design: design, previousDesign: previousDesign, designChangedAt: designChangedAt,
                      snow: snowEnabled, snowChangedAt: snowChangedAt)
    }

    func setDesign(_ d: TreeDesign) {
        guard d != design else { return }
        previousDesign = design
        designChangedAt = AppClock.now
        design = d
        defaults.set(d.rawValue, forKey: Key.design)
    }

    func nextDesign() { step(1) }
    func previousDesignStep() { step(-1) }

    func randomDesign() {
        let others = TreeDesign.allCases.filter { $0 != design }
        if let d = others.randomElement() { setDesign(d) }
    }

    private func step(_ delta: Int) {
        let n = TreeDesign.allCases.count
        setDesign(TreeDesign(rawValue: (design.rawValue + delta + n) % n)!)
    }

    func showHintOnFirstLaunch() {
        guard !defaults.bool(forKey: Key.hintShown) else { return }
        defaults.set(true, forKey: Key.hintShown)
        showHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in self?.showHint = false }
    }
}
