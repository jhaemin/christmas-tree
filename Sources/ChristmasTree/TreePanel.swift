import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var state: AppState
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            let snapshot = state.snapshot
            let current = TreeLayer.make(snapshot.design, viewSize: geo.size, scale: displayScale)
            let previous = snapshot.previousDesign.map { TreeLayer.make($0, viewSize: geo.size, scale: displayScale) }
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !state.isVisible)) { timeline in
                let t = timeline.date.timeIntervalSince(AppClock.start)
                Canvas { ctx, size in
                    SceneRenderer.draw(&ctx, size: size, t: t, scene: snapshot, current: current, previous: previous)
                }
            }
        }
        .overlay(alignment: .top) {
            if state.showHint {
                Text(L("Drag to move") + "\n" + L("Double-click: next tree · Right-click: menu"))
                    .font(.system(size: 10, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: state.showHint)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// SwiftUI 뷰를 담되 마우스 입력은 AppKit에서 직접 처리한다 (드래그 이동, 더블클릭, 우클릭 메뉴)
final class TreeHostingView: NSHostingView<RootView> {
    var onDoubleClick: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showMenu(event)
        } else if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) { showMenu(event) }

    private func showMenu(_ event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

final class TreePanel: NSPanel {
    let host: TreeHostingView
    private let state: AppState
    private let originKey = "windowOrigin"

    init(state: AppState) {
        self.state = state
        host = TreeHostingView(rootView: RootView(state: state))
        host.sizingOptions = []
        super.init(contentRect: NSRect(origin: .zero, size: state.size.cgSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = state.alwaysOnTop ? .floating : .normal
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = true
        contentView = host

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self,
                                               queue: .main) { [weak self] _ in self?.saveOrigin() }
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: self,
                                               queue: .main) { [weak self] _ in
            guard let self else { return }
            self.state.isVisible = self.occlusionState.contains(.visible)
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.ensureOnScreen() }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func saveOrigin() {
        UserDefaults.standard.set(NSStringFromPoint(frame.origin), forKey: originKey)
    }

    func restorePosition() {
        if let s = UserDefaults.standard.string(forKey: originKey) {
            let f = NSRect(origin: NSPointFromString(s), size: frame.size)
            if isVisibleOnSomeScreen(f) {
                setFrameOrigin(f.origin)
                return
            }
        }
        moveToDefaultPosition()
    }

    func moveToDefaultPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        setFrameOrigin(NSPoint(x: vf.maxX - frame.width - 30, y: vf.minY + 12))
        saveOrigin()
    }

    private func isVisibleOnSomeScreen(_ f: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersection(f).width > 40 && $0.visibleFrame.intersection(f).height > 40 }
    }

    private func ensureOnScreen() {
        if !isVisibleOnSomeScreen(frame) { moveToDefaultPosition() }
    }

    /// 크기를 바꿀 때 바닥 가운데를 기준으로 유지한다
    func apply(size: CGSize) {
        var f = frame
        let midX = f.midX
        f.size = size
        f.origin.x = midX - size.width / 2
        setFrame(f, display: true, animate: false)
        ensureOnScreen()
        saveOrigin()
    }
}
