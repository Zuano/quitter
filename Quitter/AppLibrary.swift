//
//  AppLibrary.swift
//  Quitter
//
//  Scans known application folders to provide a list of available apps.
//  Durchsucht die App-Ordner und liefert eine Liste verfügbarer Apps.
//

import AppKit

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let path: String

    /// Loaded lazily from the path
    /// Wird bei Bedarf vom Pfad geladen
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}

enum AppLibrary {
    /// Scan standard application folders for .app bundles.
    /// Durchsucht die üblichen App-Ordner nach .app-Bundles.
    static func scanInstalledApps() -> [InstalledApp] {
        var folders = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]

        // ~/Applications too, if it exists
        // Auch ~/Applications, falls vorhanden
        if let userAppsURL = FileManager.default.urls(
            for: .applicationDirectory,
            in: .userDomainMask
        ).first {
            folders.append(userAppsURL.path)
        }

        var apps: [InstalledApp] = []
        var seenBundleIDs = Set<String>()

        for folder in folders {
            for app in scanFolder(folder) {
                // De-duplicate – same bundle ID may exist in multiple folders
                // Doppelte vermeiden – gleiche Bundle-ID kann in mehreren Ordnern liegen
                if seenBundleIDs.insert(app.bundleIdentifier).inserted {
                    apps.append(app)
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Recursively scan up to `maxDepth` levels, so apps inside subfolders like
    /// "/Applications/Epson Software/Epson Scan 2.app" are also found.
    /// Rekursiver Scan bis Tiefe `maxDepth`, damit auch Apps in Unterordnern
    /// wie "/Programme/Epson Software/Epson Scan 2.app" gefunden werden.
    private static func scanFolder(_ path: String, depth: Int = 0, maxDepth: Int = 3) -> [InstalledApp] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var found: [InstalledApp] = []
        for item in contents {
            // Skip hidden files like .DS_Store
            // Versteckte Dateien wie .DS_Store überspringen
            if item.hasPrefix(".") { continue }

            let fullPath = (path as NSString).appendingPathComponent(item)

            if item.hasSuffix(".app") {
                // It's an app bundle – read its info
                // Es ist eine App – Infos auslesen
                guard let bundle = Bundle(path: fullPath),
                      let bundleID = bundle.bundleIdentifier else { continue }

                let displayName = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? (item as NSString).deletingPathExtension

                found.append(InstalledApp(
                    name: displayName,
                    bundleIdentifier: bundleID,
                    path: fullPath
                ))
            } else if depth < maxDepth {
                // Could be a subfolder – check if it's a directory and recurse
                // Könnte ein Unterordner sein – prüfen und rekursiv durchsuchen
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    found.append(contentsOf: scanFolder(fullPath, depth: depth + 1, maxDepth: maxDepth))
                }
            }
        }
        return found
    }
}
