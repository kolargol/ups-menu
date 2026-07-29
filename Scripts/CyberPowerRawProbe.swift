import Foundation
import IOKit.hid

struct HIDReading {
    let page: Int
    let usage: Int
    let reportID: Int
    let type: Int
    let value: Int64
    let logicalMin: Int
    let logicalMax: Int
    let unit: Int
    let exponent: Int
}

let vendorID = 0x0764
let productID = 0x0501
let showRawValues = CommandLine.arguments.contains("--raw")
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matching = [
    kIOHIDVendorIDKey as String: vendorID,
    kIOHIDProductIDKey as String: productID,
] as CFDictionary

IOHIDManagerSetDeviceMatching(manager, matching)
let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard managerResult == kIOReturnSuccess else {
    fputs("Unable to open IOHIDManager: \(managerResult)\n", stderr)
    exit(1)
}

guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else {
    fputs("CyberPower UPS 0764:0501 was not found.\n", stderr)
    exit(2)
}

for device in devices {
    let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) ?? "unknown" as CFTypeRef
    print("Device: \(product) [0764:0501]")

    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openResult == kIOReturnSuccess else {
        fputs("Unable to open HID device: \(openResult)\n", stderr)
        continue
    }

    guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else {
        continue
    }

    var readings: [HIDReading] = []
    for element in elements {
        let page = IOHIDElementGetUsagePage(element)
        guard page == 0x84 || page == 0x85 || page >= 0xff00 else {
            continue
        }

        let valuePointer = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
        let valueResult = IOHIDDeviceGetValue(device, element, valuePointer)
        guard valueResult == kIOReturnSuccess else {
            valuePointer.deallocate()
            continue
        }
        let value = valuePointer.pointee.takeUnretainedValue()
        valuePointer.deallocate()

        readings.append(HIDReading(
            page: Int(page),
            usage: Int(IOHIDElementGetUsage(element)),
            reportID: Int(IOHIDElementGetReportID(element)),
            type: Int(IOHIDElementGetType(element).rawValue),
            value: Int64(IOHIDValueGetIntegerValue(value)),
            logicalMin: IOHIDElementGetLogicalMin(element),
            logicalMax: IOHIDElementGetLogicalMax(element),
            unit: Int(IOHIDElementGetUnit(element)),
            exponent: Int(IOHIDElementGetUnitExponent(element))
        ))
    }

    func value(reportID: Int, page: Int, usage: Int) -> Int64? {
        readings.first {
            $0.reportID == reportID && $0.page == page && $0.usage == usage
        }?.value
    }

    let online = value(reportID: 11, page: 0x85, usage: 0xd0) == 1
    let batteryCharge = value(reportID: 8, page: 0x85, usage: 0x66)
    let runtimeSeconds = value(reportID: 8, page: 0x85, usage: 0x68)
    let inputVoltage = value(reportID: 15, page: 0x84, usage: 0x30)
    let outputVoltage = value(reportID: 18, page: 0x84, usage: 0x30)
    let loadPercent = value(reportID: 19, page: 0x84, usage: 0x35)
    let nominalWatts = value(reportID: 24, page: 0x84, usage: 0x44)

    print("State: \(online ? "online" : "on battery")")
    if let batteryCharge {
        print("Battery charge: \(batteryCharge)%")
    }
    if let runtimeSeconds {
        print(String(format: "Estimated runtime: %lld s (%.1f min)", runtimeSeconds, Double(runtimeSeconds) / 60))
    }
    if let inputVoltage {
        print("Input voltage: \(inputVoltage) V")
    }
    if let outputVoltage {
        print("Output voltage: \(outputVoltage) V")
    }
    if let loadPercent {
        print("Load: \(loadPercent)%")
    }
    if let nominalWatts {
        print("Nominal active power: \(nominalWatts) W")
    }
    if let loadPercent, let nominalWatts {
        let estimatedWatts = Double(loadPercent * nominalWatts) / 100
        print(String(format: "Estimated output power: %.1f W", estimatedWatts))
    }

    if showRawValues {
        print("\npage usage report type value logical_min logical_max unit exponent")
        for reading in readings {
            print(String(
                format: "0x%04x 0x%04x %3d %4d %12lld %11ld %11ld 0x%08x %3d",
                reading.page,
                reading.usage,
                reading.reportID,
                reading.type,
                reading.value,
                reading.logicalMin,
                reading.logicalMax,
                reading.unit,
                reading.exponent
            ))
        }
    }

    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
}

IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))