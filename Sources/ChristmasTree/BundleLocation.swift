import Foundation

/* The app shipped as "ChristmasTree.app" in 1.0.0 and as "Christmas Tree.app"
   since. Sparkle installs an update at the existing path (its name
   normalization is compiled out of the prebuilt framework), so an install
   that updated from 1.0.0 would keep the old name forever. On launch, rename
   such a bundle and relaunch from the new path. */
enum BundleLocation {
    static let legacyName = "ChristmasTree.app"
    static let currentName = "Christmas Tree.app"

    /// Returns true when a relaunch from the renamed bundle is under way and
    /// this process should exit without starting up.
    static func renameLegacyBundleIfNeeded() -> Bool {
        let fm = FileManager.default
        let url = Bundle.main.bundleURL
        // Only our own old default name — a name the user chose stays.
        // Translocated (quarantined, not yet moved) apps run from a
        // read-only mount; leave them alone.
        guard url.lastPathComponent == legacyName,
              !url.path.contains("/AppTranslocation/")
        else { return false }

        let parent = url.deletingLastPathComponent()
        let target = parent.appendingPathComponent(currentName)
        guard fm.isWritableFile(atPath: parent.path), !fm.fileExists(atPath: target.path) else { return false }
        do {
            try fm.moveItem(at: url, to: target)
        } catch {
            return false
        }

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-n", target.path]
        do {
            try open.run()
        } catch {
            // Couldn't relaunch: put the bundle back and carry on as before.
            try? fm.moveItem(at: target, to: url)
            return false
        }
        return true
    }
}
