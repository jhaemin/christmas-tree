import Foundation

/* UI strings pass through here: the English source text is the key, so a
   missing translation (or a language the app doesn't ship) falls back to
   English by construction. Translations live in
   Resources/<lang>.lproj/Localizable.strings inside the SwiftPM resource
   bundle, which follows the user's system language. */

/* Resolved by hand instead of `Bundle.module`: the accessor SwiftPM
   generates for executable targets only looks at the .app root and the
   build machine's absolute path — never Contents/Resources, where
   Scripts/bundle.sh puts the bundle — and traps when it finds nothing. */
private let localizationBundle: Bundle = {
    if let url = Bundle.main.resourceURL?
        .appendingPathComponent("ChristmasTree_ChristmasTree.bundle"),
        let bundle = Bundle(url: url)
    {
        return bundle
    }
    /* `swift run` and dev builds: the generated accessor knows the
       build-directory layout. */
    return .module
}()

func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: localizationBundle, comment: "")
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}
