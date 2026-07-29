import Foundation

struct HIDElementAddress: Hashable, Sendable {
    let reportID: Int
    let page: Int
    let usage: Int
}

struct NamedHIDElement: Sendable {
    let name: String
    let address: HIDElementAddress
}

struct UPSDeviceProfile: Sendable {
    let name: String
    let vendorID: Int
    let productID: Int
    let online: HIDElementAddress
    let batteryCharge: HIDElementAddress
    let runtimeSeconds: HIDElementAddress
    let inputVoltage: HIDElementAddress
    let outputVoltage: HIDElementAddress
    let loadPercent: HIDElementAddress
    let nominalWatts: HIDElementAddress
    let nominalVoltage: HIDElementAddress
    let lowTransferVoltage: HIDElementAddress
    let highTransferVoltage: HIDElementAddress
    let charging: HIDElementAddress
    let discharging: HIDElementAddress
    let fullyCharged: HIDElementAddress
    let batteryLow: HIDElementAddress
    let overloaded: HIDElementAddress
    let boosting: HIDElementAddress

    var requiredTelemetry: [NamedHIDElement] {
        [
            NamedHIDElement(name: "online status", address: online),
            NamedHIDElement(name: "battery charge", address: batteryCharge),
            NamedHIDElement(name: "estimated runtime", address: runtimeSeconds),
            NamedHIDElement(name: "input voltage", address: inputVoltage),
            NamedHIDElement(name: "output voltage", address: outputVoltage),
            NamedHIDElement(name: "load percentage", address: loadPercent),
            NamedHIDElement(name: "rated active power", address: nominalWatts),
        ]
    }

    static let cyberPowerCP900EPFCLCD = UPSDeviceProfile(
        name: "CyberPower CP900EPFCLCD",
        vendorID: 0x0764,
        productID: 0x0501,
        online: HIDElementAddress(reportID: 11, page: 0x85, usage: 0xd0),
        batteryCharge: HIDElementAddress(reportID: 8, page: 0x85, usage: 0x66),
        runtimeSeconds: HIDElementAddress(reportID: 8, page: 0x85, usage: 0x68),
        inputVoltage: HIDElementAddress(reportID: 15, page: 0x84, usage: 0x30),
        outputVoltage: HIDElementAddress(reportID: 18, page: 0x84, usage: 0x30),
        loadPercent: HIDElementAddress(reportID: 19, page: 0x84, usage: 0x35),
        nominalWatts: HIDElementAddress(reportID: 24, page: 0x84, usage: 0x44),
        nominalVoltage: HIDElementAddress(reportID: 14, page: 0x84, usage: 0x40),
        lowTransferVoltage: HIDElementAddress(reportID: 16, page: 0x84, usage: 0x53),
        highTransferVoltage: HIDElementAddress(reportID: 16, page: 0x84, usage: 0x54),
        charging: HIDElementAddress(reportID: 11, page: 0x85, usage: 0x44),
        discharging: HIDElementAddress(reportID: 11, page: 0x85, usage: 0x45),
        fullyCharged: HIDElementAddress(reportID: 11, page: 0x85, usage: 0x46),
        batteryLow: HIDElementAddress(reportID: 11, page: 0x85, usage: 0x42),
        overloaded: HIDElementAddress(reportID: 23, page: 0x84, usage: 0x65),
        boosting: HIDElementAddress(reportID: 23, page: 0x84, usage: 0x6e)
    )

    static let supported = [cyberPowerCP900EPFCLCD]

    static func matching(vendorID: Int, productID: Int) -> UPSDeviceProfile? {
        supported.first { $0.vendorID == vendorID && $0.productID == productID }
    }
}
