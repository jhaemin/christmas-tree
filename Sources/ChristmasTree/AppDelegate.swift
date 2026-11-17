import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState.shared
    private let music = MusicPlayer()
    private let updater = UpdaterController()
    private var panel: TreePanel!
    private var statusItem: NSStatusItem!
    private var bag = Set<AnyCancellable>()
    private var thumbnails: [TreeDesign: NSImage] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = TreePanel(state: state)
        panel.host.onDoubleClick = { [weak self] in self?.state.nextDesign() }
        panel.host.menuProvider = { [weak self] in
            let menu = NSMenu()
            self?.populate(menu)
            return menu
        }
        panel.restorePosition()
        panel.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "tree.fill", accessibilityDescription: L("Christmas Tree")) {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "🎄"
            }
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        bind()
        state.showHintOnFirstLaunch()
    }

    private func bind() {
        state.$size.dropFirst().sink { [weak self] s in self?.panel.apply(size: s.cgSize) }.store(in: &bag)
        state.$alwaysOnTop.sink { [weak self] on in self?.panel.level = on ? .floating : .normal }.store(in: &bag)
        state.$volume.sink { [weak self] v in self?.music.volume = v.gain }.store(in: &bag)
        state.$musicEnabled.sink { [weak self] on in
            guard let self else { return }
            if on { self.music.play(selection: self.state.song) } else { self.music.stop() }
        }.store(in: &bag)
        state.$song.dropFirst().sink { [weak self] song in
            guard let self, self.state.musicEnabled else { return }
            self.music.play(selection: song)
        }.store(in: &bag)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu)
    }

    private func item(_ title: String, _ action: Selector?, tag: Int = 0, on: Bool = false, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        it.tag = tag
        it.state = on ? .on : .off
        return it
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        items.forEach(sub.addItem)
        it.submenu = sub
        return it
    }

    private func populate(_ menu: NSMenu) {
        menu.autoenablesItems = false

        let header = NSMenuItem(title: christmasCountdown(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let designItems = TreeDesign.allCases.map { d -> NSMenuItem in
            let it = item(d.name, #selector(selectDesign(_:)), tag: d.rawValue, on: d == state.design)
            it.image = thumbnail(d)
            return it
        }
        menu.addItem(submenu(L("Tree Design (%@)", state.design.name), designItems))
        menu.addItem(item(L("Next Design"), #selector(nextDesign)))
        menu.addItem(item(L("Previous Design"), #selector(previousDesign)))
        menu.addItem(item(L("Random Design"), #selector(randomDesign)))
        menu.addItem(.separator())

        menu.addItem(item("❄️ " + L("Snowfall"), #selector(toggleSnow), on: state.snowEnabled))
        menu.addItem(item("🎵 " + L("Play Music"), #selector(toggleMusic), on: state.musicEnabled))
        if music.isPlaying, let idx = music.currentSong {
            let now = NSMenuItem(title: "    ♪ \(Songs.all[idx].title)", action: nil, keyEquivalent: "")
            now.isEnabled = false
            menu.addItem(now)
        }
        var songItems = [item(L("Play All"), #selector(selectSong(_:)), tag: -1, on: state.song == -1)]
        songItems.append(.separator())
        for (i, s) in Songs.all.enumerated() {
            songItems.append(item(s.title, #selector(selectSong(_:)), tag: i, on: state.song == i))
        }
        menu.addItem(submenu(L("Song"), songItems))
        menu.addItem(submenu(L("Volume"), Volume.allCases.map {
            item($0.name, #selector(selectVolume(_:)), tag: $0.rawValue, on: state.volume == $0)
        }))
        menu.addItem(.separator())

        menu.addItem(submenu(L("Size"), TreeSize.allCases.map {
            item($0.name, #selector(selectSize(_:)), tag: $0.rawValue, on: state.size == $0)
        }))
        menu.addItem(item(L("Always on Top"), #selector(toggleOnTop), on: state.alwaysOnTop))
        menu.addItem(item(L("Launch at Login"), #selector(toggleLoginItem), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(item(L("Reset Position"), #selector(resetPosition)))
        menu.addItem(.separator())
        menu.addItem(updater.makeMenuItem())
        menu.addItem(item(L("Quit Christmas Tree"), #selector(quit), key: "q"))
    }

    private func christmasCountdown() -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let year = cal.component(.year, from: today)
        var xmas = cal.date(from: DateComponents(year: year, month: 12, day: 25))!
        if today > xmas { xmas = cal.date(from: DateComponents(year: year + 1, month: 12, day: 25))! }
        let days = cal.dateComponents([.day], from: today, to: xmas).day ?? 0
        switch days {
        case 0: return "🎅 " + L("Merry Christmas!")
        case 1: return "🎅 " + L("1 day until Christmas")
        default: return "🎅 " + L("%d days until Christmas", days)
        }
    }

    private func thumbnail(_ d: TreeDesign) -> NSImage? {
        if let img = thumbnails[d] { return img }
        let renderer = ImageRenderer(content: DesignStill(design: d, size: CGSize(width: 24, height: 30), t: 2))
        renderer.scale = 2
        let img = renderer.nsImage
        thumbnails[d] = img
        return img
    }

    // MARK: - Actions

    @objc private func selectDesign(_ sender: NSMenuItem) {
        if let d = TreeDesign(rawValue: sender.tag) { state.setDesign(d) }
    }
    @objc private func nextDesign() { state.nextDesign() }
    @objc private func previousDesign() { state.previousDesignStep() }
    @objc private func randomDesign() { state.randomDesign() }
    @objc private func toggleSnow() { state.snowEnabled.toggle() }
    @objc private func toggleMusic() { state.musicEnabled.toggle() }
    @objc private func selectSong(_ sender: NSMenuItem) {
        state.song = sender.tag
        if !state.musicEnabled { state.musicEnabled = true }
    }
    @objc private func selectVolume(_ sender: NSMenuItem) { state.volume = Volume(rawValue: sender.tag) ?? .medium }
    @objc private func selectSize(_ sender: NSMenuItem) { state.size = TreeSize(rawValue: sender.tag) ?? .medium }
    @objc private func toggleOnTop() { state.alwaysOnTop.toggle() }
    @objc private func resetPosition() { panel.moveToDefaultPosition() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("Couldn’t change the login item")
            alert.informativeText = L("Move the app to the Applications folder and try again.") + "\n(\(error.localizedDescription))"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
