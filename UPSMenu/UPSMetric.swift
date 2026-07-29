import Foundation

enum UPSMetric: String, CaseIterable, Identifiable {
    case estimatedPower
    case load
    case battery
    case runtime
    case inputVoltage
    case outputVoltage
    case nominalPower
    case nominalVoltage
    case transferRange
    case batteryState
    case powerCondition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estimatedPower: "Power"
        case .load: "Load"
        case .battery: "Battery"
        case .runtime: "Runtime"
        case .inputVoltage: "Input"
        case .outputVoltage: "Output"
        case .nominalPower: "Rated Power"
        case .nominalVoltage: "Nominal Voltage"
        case .transferRange: "Transfer Range"
        case .batteryState: "Battery State"
        case .powerCondition: "Power Condition"
        }
    }

    var symbol: String {
        switch self {
        case .estimatedPower: "bolt"
        case .load: "gauge.with.dots.needle.33percent"
        case .battery: "battery.100percent"
        case .runtime: "clock"
        case .inputVoltage: "arrow.down.to.line"
        case .outputVoltage: "arrow.up.to.line"
        case .nominalPower: "bolt.badge.checkmark"
        case .nominalVoltage: "waveform.path.ecg"
        case .transferRange: "arrow.up.and.down"
        case .batteryState: "batteryblock"
        case .powerCondition: "powerplug"
        }
    }

    func value(for reading: UPSReading) -> String? {
        switch self {
        case .estimatedPower:
            return String(format: "%.1f W", reading.estimatedWatts)
        case .load:
            return "\(reading.loadPercent)%"
        case .battery:
            return "\(reading.batteryCharge)%"
        case .runtime:
            return Self.runtimeText(reading.runtimeSeconds)
        case .inputVoltage:
            return "\(reading.inputVoltage) V"
        case .outputVoltage:
            return "\(reading.outputVoltage) V"
        case .nominalPower:
            return "\(reading.nominalWatts) W"
        case .nominalVoltage:
            return reading.nominalVoltage.map { "\($0) V" }
        case .transferRange:
            if let low = reading.lowTransferVoltage, let high = reading.highTransferVoltage {
                return "\(low)-\(high) V"
            } else {
                return nil
            }
        case .batteryState:
            guard reading.isCharging != nil
                    || reading.isDischarging != nil
                    || reading.isFullyCharged != nil else { return nil }
            if reading.isDischarging == true { return "Discharging" }
            if reading.isCharging == true { return "Charging" }
            if reading.isFullyCharged == true { return "Fully Charged" }
            return "Idle"
        case .powerCondition:
            guard reading.isOverloaded != nil
                    || reading.isBoosting != nil
                    || reading.isBatteryLow != nil else { return nil }
            if reading.isOverloaded == true { return "Overload" }
            if reading.isBoosting == true { return "Boosting" }
            if reading.isBatteryLow == true { return "Low Battery" }
            return "Normal"
        }
    }

    func menuBarValue(for reading: UPSReading) -> String? {
        switch self {
        case .estimatedPower, .load, .battery, .runtime, .inputVoltage, .outputVoltage:
            value(for: reading)
        default:
            nil
        }
    }

    static let menuBarChoices: [UPSMetric] = [
        .estimatedPower, .load, .battery, .runtime, .inputVoltage, .outputVoltage,
    ]

    static let defaultVisibleIDs = [
        estimatedPower, load, battery, runtime, inputVoltage, outputVoltage,
        nominalPower, batteryState, powerCondition,
    ].map(\.rawValue).joined(separator: ",")

    static func visibleMetrics(from storedValue: String) -> [UPSMetric] {
        let selected = Set(storedValue.split(separator: ",").map(String.init))
        return allCases.filter { selected.contains($0.rawValue) }
    }

    private static func runtimeText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
    }
}

