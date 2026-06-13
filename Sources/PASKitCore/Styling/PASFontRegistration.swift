//
//  PASFontRegistration.swift
//  PASKitCore
//
//  Runtime registration of bundled font files. Works around Xcode's
//  GENERATE_INFOPLIST_FILE not emitting UIAppFonts — bundled custom fonts
//  silently fail to load unless registered with CTFontManager at launch.
//

import CoreText
import Foundation

/// Registers bundled font files at launch.
///
/// ```swift
/// init() {
///     PASFontRegistration.registerBundledFonts(named: ["BrushScript.ttf", "SongTi.otf"])
/// }
/// ```
public enum PASFontRegistration {
    /// Registers each font file with the font manager for this process.
    /// Missing files and registration failures are logged, not thrown —
    /// callers ship system-font fallbacks anyway. Re-registering an
    /// already-registered font logs a benign error and is harmless.
    ///
    /// - Parameters:
    ///   - fileNames: Font file names **including extension**
    ///     (e.g. `"NotoSerifSC-VariableFont_wght.ttf"`).
    ///   - bundle: Defaults to `.main`.
    public static func registerBundledFonts(named fileNames: [String], bundle: Bundle = .main) {
        let log = PASLogger.make(category: "fonts")
        for fileName in fileNames {
            let resource = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            guard let url = bundle.url(forResource: resource, withExtension: ext) else {
                log.warning("font file not found in bundle: \(fileName, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let description = (error?.takeRetainedValue()).map(String.init(describing:)) ?? "unknown"
                log.error("font registration failed for \(fileName, privacy: .public): \(description, privacy: .public)")
            }
        }
    }
}
