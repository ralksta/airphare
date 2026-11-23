import AppKit
import CoreLocation
import Foundation
import AirPhareCore
import UserNotifications

@MainActor
final class AlertNotificationManager: NSObject, CLLocationManagerDelegate {
    private var lastSentByCategory: [AlertCategory: Date] = [:]
    private let cooldownSeconds: TimeInterval = 30 * 60
    private let locationManager = CLLocationManager()
    var onLocationAuthChanged: (() -> Void)?

    var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestPermissionsIfAvailable() {
        if canUseUserNotifications {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func requestLocationForSSID() {
        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            openLocationPrivacySettings()
            return
        }
        locationManager.requestWhenInUseAuthorization()
        // Trigger macOS prompt reliably for LSUIElement apps
        locationManager.startUpdatingLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.locationManager.stopUpdatingLocation()
        }
    }

    func openLocationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.locationManager.stopUpdatingLocation()
            self?.onLocationAuthChanged?()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            self?.locationManager.stopUpdatingLocation()
            self?.onLocationAuthChanged?()
        }
    }

    func notifyIfNeeded(alerts: [HealthAlert], enabled: Bool) {
        guard enabled, canUseUserNotifications else { return }
        let now = Date()

        for alert in alerts where alert.severity >= .warning {
            if let last = lastSentByCategory[alert.category],
               now.timeIntervalSince(last) < cooldownSeconds {
                continue
            }
            lastSentByCategory[alert.category] = now

            let content = UNMutableNotificationContent()
            content.title = "AirPhare: \(alert.title)"
            content.body = "\(alert.message) \(alert.actionHint)"
            content.sound = alert.severity == .critical ? .default : nil

            let request = UNNotificationRequest(
                identifier: "airphare-\(alert.category.rawValue)-\(Int(now.timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func resetCooldowns() {
        lastSentByCategory.removeAll()
    }
}
