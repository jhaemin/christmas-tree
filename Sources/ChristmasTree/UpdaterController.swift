import AppKit
import Sparkle

/* Sparkle auto-update, isolated in this file so it can be compiled out
   wholesale along with the Sparkle dependency (e.g. for an App Store build,
   which must not ship a self-updater). */
@MainActor
final class UpdaterController {
    private let controller: SPUStandardUpdaterController

    init() {
        /* Non-bundled dev builds (`swift run`) have no Info.plist, so Sparkle
           has no feed URL or public key there — don't start the updater, or
           it just logs errors. The menu item stays disabled via Sparkle's
           own menu validation. */
        controller = SPUStandardUpdaterController(
            startingUpdater: Bundle.main.bundleIdentifier != nil,
            updaterDelegate: nil, userDriverDelegate: nil)
    }

    func makeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: L("Check for Updates…"),
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        item.target = controller
        return item
    }
}
