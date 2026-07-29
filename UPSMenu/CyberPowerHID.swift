import Foundation
import IOKit.hid

struct UPSReading: Equatable {
    let model: String
    let isOnline: Bool
    let batteryCharge: Int
    let runtimeSeconds: Int
    let inputVoltage: Int
    let outputVoltage: Int
    let loadPercent: Int
    let nominalWatts: Int
    let nominalVoltage: Int?
    let lowTransferVoltage: Int?
    let highTransferVoltage: Int?
    let isCharging: Bool?
    let isDischarging: Bool?
    let isFullyCharged: Bool?
    let isBatteryLow: Bool?
    let isOverloaded: Bool?
    let isBoosting: Bool?
    let measuredAt: Date

    var estimatedWatts: Double {
        Double(loadPercent * nominalWatts) / 100
    }
}

enum UPSReadError: LocalizedError {
    case managerUnavailable(IOReturn)
    case deviceNotFound
    case deviceUnavailable(IOReturn)
    case incompleteReport

    var errorDescription: String? {
        switch self {
        case .managerUnavailable:
            "HID service unavailable"
        case .deviceNotFound:
            "UPS not connected"
        case .deviceUnavailable:
            "UPS communication unavailable"
        case .incompleteReport:
            "UPS data unavailable"
        }
    }
}

enum CyberPowerHID {
    private static let profile = UPSDeviceProfile.cyberPowerCP900EPFCLCD

    static func read() throws -> UPSReading {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey as String: profile.vendorID,
            kIOHIDProductIDKey as String: profile.productID,
        ] as CFDictionary)

        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else {
            throw UPSReadError.managerUnavailable(managerResult)
        }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first else {
            throw UPSReadError.deviceNotFound
        }

        let deviceResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard deviceResult == kIOReturnSuccess else {
            throw UPSReadError.deviceUnavailable(deviceResult)
        }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let elements = IOHIDDeviceCopyMatchingElements(
            device,
            nil,
            IOOptionBits(kIOHIDOptionsTypeNone)
        ) as? [IOHIDElement] else {
            throw UPSReadError.incompleteReport
        }

        var values: [ElementKey: Int64] = [:]
        for element in elements {
            let page = Int(IOHIDElementGetUsagePage(element))
            guard page == 0x84 || page == 0x85 else { continue }

            let valuePointer = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
            defer { valuePointer.deallocate() }
            guard IOHIDDeviceGetValue(device, element, valuePointer) == kIOReturnSuccess else {
                continue
            }

            let key = ElementKey(
                reportID: Int(IOHIDElementGetReportID(element)),
                page: page,
                usage: Int(IOHIDElementGetUsage(element))
            )
            if values[key] == nil {
                values[key] = Int64(IOHIDValueGetIntegerValue(valuePointer.pointee.takeUnretainedValue()))
            }
        }

        func required(_ address: HIDElementAddress) throws -> Int {
            guard let value = values[ElementKey(address)] else {
                throw UPSReadError.incompleteReport
            }
            return Int(value)
        }

        func optional(_ address: HIDElementAddress) -> Int? {
            values[ElementKey(address)].map(Int.init)
        }

        func flag(_ address: HIDElementAddress) -> Bool? {
            optional(address).map { $0 == 1 }
        }

        let model = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
            ?? "CyberPower UPS"

        return try UPSReading(
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            isOnline: required(profile.online) == 1,
            batteryCharge: required(profile.batteryCharge),
            runtimeSeconds: required(profile.runtimeSeconds),
            inputVoltage: required(profile.inputVoltage),
            outputVoltage: required(profile.outputVoltage),
            loadPercent: required(profile.loadPercent),
            nominalWatts: required(profile.nominalWatts),
            nominalVoltage: optional(profile.nominalVoltage),
            lowTransferVoltage: optional(profile.lowTransferVoltage),
            highTransferVoltage: optional(profile.highTransferVoltage),
            isCharging: flag(profile.charging),
            isDischarging: flag(profile.discharging),
            isFullyCharged: flag(profile.fullyCharged),
            isBatteryLow: flag(profile.batteryLow),
            isOverloaded: flag(profile.overloaded),
            isBoosting: flag(profile.boosting),
            measuredAt: Date()
        )
    }

    private struct ElementKey: Hashable {
        let reportID: Int
        let page: Int
        let usage: Int

        init(reportID: Int, page: Int, usage: Int) {
            self.reportID = reportID
            self.page = page
            self.usage = usage
        }

        init(_ address: HIDElementAddress) {
            self.init(reportID: address.reportID, page: address.page, usage: address.usage)
        }
    }
}
