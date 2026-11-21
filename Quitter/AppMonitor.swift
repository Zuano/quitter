//
//  AppMonitor.swift
//  Quitter
//
//  Core logic: observes app activation/deactivation, tracks inactivity time,
//  and quits monitored apps cleanly via NSRunningApplication.terminate().
//
//  Kernlogik: beobachtet Aktivierung/Deaktivierung von Apps, misst die
//  Inaktivitätszeit und beendet überwachte Apps sauber via terminate().
//

import AppKit
import Observation

@Observable
final class AppMonitor {
    /// All apps the user has configured for monitoring.
    /// Alle Apps, die der User zur Überwachung konfiguriert hat.
    var monitoredApps: [MonitoredApp] = []

    /// Global pause toggle – when true, no app gets quit.
    /// Globaler Pause-Schalter – wenn true, wird nichts beendet.
    var isPaused: Bool = false

    /// Per-bundle-ID timestamp of when the app became inactive.
    /// Pro Bundle-ID: Zeitpunkt, ab dem die App inaktiv ist.
    @ObservationIgnored
    private var inactiveSince: [String: Date] = [:]

    @ObservationIgnored
    private var timer: Timer?

    @ObservationIgnored
    private var observerTokens: [NSObjectProtocol] = []

    private let storageKey = "monitoredApps"

    init() {
        loadFromUserDefaults()
        setupWorkspaceObservers()
        seedInactiveStateForRunningApps()
        startTickTimer()
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for token in observerTokens {
            center.removeObserver(token)
        }
        timer?.invalidate()
    }

    // MARK: - Workspace observers
    // MARK: - Workspace-Beobachter

    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter

        // App moved to foreground -> reset its inactivity timer
        // App in den Vordergrund -> Inaktivitäts-Timer zurücksetzen
        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let bundleID = Self.bundleID(from: note) else { return }
            self?.inactiveSince.removeValue(forKey: bundleID)
        })

        // App lost focus -> start measuring inactivity
        // App verliert Fokus -> Inaktivität ab jetzt zählen
        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let bundleID = Self.bundleID(from: note) else { return }
            self?.inactiveSince[bundleID] = Date()
        })

        // App launched -> if it's a background app (not active), start the clock
        // App startet -> wenn sie im Hintergrund läuft, Uhr ab jetzt
        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            if !app.isActive {
                self?.inactiveSince[bundleID] = Date()
            }
        })

        // App quit -> drop tracked state
        // App beendet -> State wegwerfen
        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let bundleID = Self.bundleID(from: note) else { return }
            self?.inactiveSince.removeValue(forKey: bundleID)
        })
    }

    /// At startup, treat any already-running, non-active monitored app as inactive starting "now".
    /// Beim Start: bereits laufende, nicht-aktive Apps gelten ab jetzt als inaktiv.
    private func seedInactiveStateForRunningApps() {
        let now = Date()
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if !app.isActive {
                inactiveSince[bundleID] = now
            }
        }
    }

    private static func bundleID(from notification: Notification) -> String? {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return app?.bundleIdentifier
    }

    // MARK: - Timer
    // MARK: - Timer

    private func startTickTimer() {
        // Check every 10 seconds – fine-grained enough for minute-based timeouts
        // Alle 10 Sekunden prüfen – fein genug für Minuten-basierte Timeouts
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkTimeouts()
        }
    }

    private func checkTimeouts() {
        guard !isPaused else { return }
        let now = Date()

        for monitored in monitoredApps where monitored.isEnabled {
            guard let inactiveStart = inactiveSince[monitored.bundleIdentifier] else { continue }
            let inactiveSeconds = now.timeIntervalSince(inactiveStart)
            let timeoutSeconds = TimeInterval(monitored.timeoutMinutes * 60)
            if inactiveSeconds >= timeoutSeconds {
                quit(bundleID: monitored.bundleIdentifier)
                inactiveSince.removeValue(forKey: monitored.bundleIdentifier)
            }
        }
    }

    /// Send a clean Quit Apple Event – same as Cmd+Q.
    /// Sendet ein sauberes Quit-Apple-Event – wie Cmd+Q.
    private func quit(bundleID: String) {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        for app in runningApps {
            _ = app.terminate()
        }
    }

    // MARK: - CRUD
    // MARK: - Verwalten

    func add(_ app: MonitoredApp) {
        // Don't add duplicates by bundle ID
        // Keine Duplikate nach Bundle-ID hinzufügen
        guard !monitoredApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        monitoredApps.append(app)
        saveToUserDefaults()
    }

    func remove(_ app: MonitoredApp) {
        monitoredApps.removeAll { $0.id == app.id }
        saveToUserDefaults()
    }

    func update(_ app: MonitoredApp) {
        if let idx = monitoredApps.firstIndex(where: { $0.id == app.id }) {
            monitoredApps[idx] = app
            saveToUserDefaults()
        }
    }

    /// Persist any changes – called from views via onChange.
    /// Speichert Änderungen – wird aus Views via onChange gerufen.
    func persist() {
        saveToUserDefaults()
    }

    // MARK: - Status helpers for the UI
    // MARK: - Status-Hilfen für die Oberfläche

    /// Remaining seconds before the app would be quit, or nil if it's currently active or not running.
    /// Verbleibende Sekunden bis zum Beenden, oder nil wenn aktiv/nicht laufend.
    func remainingSeconds(for app: MonitoredApp) -> TimeInterval? {
        guard let start = inactiveSince[app.bundleIdentifier] else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let total = TimeInterval(app.timeoutMinutes * 60)
        return max(0, total - elapsed)
    }

    func isRunning(_ app: MonitoredApp) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty
    }

    // MARK: - Persistence
    // MARK: - Speichern/Laden

    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(monitoredApps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MonitoredApp].self, from: data) else { return }
        monitoredApps = decoded
    }
}
