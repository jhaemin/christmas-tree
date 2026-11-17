import AppKit
import SwiftUI

// 개발용 명령:
//   --render-previews <dir>   모든 디자인을 PNG로 저장
//   --render-audio <dir>      모든 곡을 WAV로 저장
let args = CommandLine.arguments

func argument(after flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

if let dir = argument(after: "--render-previews") {
    MainActor.assumeIsolated { DevTools.renderPreviews(to: dir) }
    exit(0)
}
if let dir = argument(after: "--render-audio") {
    DevTools.renderAudio(to: dir)
    exit(0)
}

if BundleLocation.renameLegacyBundleIfNeeded() { exit(0) }

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
