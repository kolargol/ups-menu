import Foundation

@MainActor
final class UPSMonitor: NSObject, ObservableObject {
    @Published private(set) var reading: UPSReading?
    @Published private(set) var errorMessage: String?

    private var timer: Timer?

    override init() {
        super.init()
        refresh()
        timer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.5
    }

    var menuSymbol: String {
        guard let reading else { return "exclamationmark.triangle" }
        return reading.isOnline ? "bolt.shield.fill" : "battery.50percent"
    }

    @objc private func refresh() {
        do {
            reading = try CyberPowerHID.read()
            errorMessage = nil
        } catch {
            reading = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
