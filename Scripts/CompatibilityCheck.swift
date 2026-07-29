import Foundation
import IOKit.hid

private struct GenericRequirement {
    let name: String
    let page: Int
    let usage: Int
    let minimumReports: Int
}

@main
struct CompatibilityCheck {
    private static let diagnosticMode = CommandLine.arguments.contains("--diagnostic")
    private static let genericRequirements = [
        GenericRequirement(name: "online status", page: 0x85, usage: 0xd0, minimumReports: 1),
        GenericRequirement(name: "battery charge", page: 0x85, usage: 0x66, minimumReports: 1),
        GenericRequirement(name: "estimated runtime", page: 0x85, usage: 0x68, minimumReports: 1),
        GenericRequirement(name: "input and output voltage", page: 0x84, usage: 0x30, minimumReports: 2),
        GenericRequirement(name: "load percentage", page: 0x84, usage: 0x35, minimumReports: 1),
        GenericRequirement(name: "rated active power", page: 0x84, usage: 0x44, minimumReports: 1),
    ]

    static func main() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, [
            [kIOHIDDeviceUsagePageKey as String: 0x84],
            [kIOHIDDeviceUsagePageKey as String: 0x85],
        ] as CFArray)

        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else {
            fail("Unable to open macOS HID service (IOKit error \(managerResult)).", code: 1)
        }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            fail("No HID devices were returned by macOS.", code: 2)
        }

        let powerDevices = devices.compactMap(inspectDevice).sorted {
            ($0.manufacturer, $0.product) < ($1.manufacturer, $1.product)
        }

        guard !powerDevices.isEmpty else {
            fail("No USB HID Power Device was found. Connect the UPS by USB and try again.", code: 2)
        }

        var hasSupportedDevice = false
        for (index, device) in powerDevices.enumerated() {
            if index > 0 { print("") }
            print("Device: \(device.manufacturer) \(device.product)")
            print(String(format: "USB ID: %04x:%04x", device.vendorID, device.productID))

            if let profile = UPSDeviceProfile.matching(
                vendorID: device.vendorID,
                productID: device.productID
            ) {
                let missing = profile.requiredTelemetry.filter {
                    !device.readableAddresses.contains($0.address)
                }
                if missing.isEmpty {
                    hasSupportedDevice = true
                    print("Result: SUPPORTED")
                    print("Profile: \(profile.name)")
                    print("All required telemetry reports are readable.")
                } else {
                    print("Result: KNOWN DEVICE, BUT REQUIRED REPORTS ARE UNAVAILABLE")
                    print("Profile: \(profile.name)")
                    print("Missing: \(missing.map(\.name).joined(separator: ", "))")
                }
            } else {
                let missing = genericRequirements.filter {
                    device.reportCount(page: $0.page, usage: $0.usage) < $0.minimumReports
                }
                if missing.isEmpty {
                    print("Result: CANDIDATE, NOT CURRENTLY SUPPORTED")
                    print("This device exposes the standard telemetry used by UPS Menu, but its report map has not been validated.")
                    print("Open a device-support issue and include this output plus the diagnostic report.")
                } else {
                    print("Result: NOT COMPATIBLE WITH THE CURRENT READER")
                    print("Missing standard telemetry: \(missing.map(\.name).joined(separator: ", "))")
                }
            }

            if diagnosticMode {
                printDiagnostic(device)
            }
        }

        if hasSupportedDevice {
            exit(0)
        }
        exit(3)
    }

    private static func inspectDevice(_ device: IOHIDDevice) -> InspectedDevice? {
        guard let elements = IOHIDDeviceCopyMatchingElements(
            device,
            nil,
            IOOptionBits(kIOHIDOptionsTypeNone)
        ) as? [IOHIDElement] else {
            return nil
        }

        let powerElements = elements.filter {
            let page = Int(IOHIDElementGetUsagePage($0))
            return page == 0x84 || page == 0x85
        }
        guard !powerElements.isEmpty else { return nil }

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        var readableAddresses = Set<HIDElementAddress>()
        var reportsByUsage: [UsageKey: Set<Int>] = [:]
        var diagnostics: [ElementDiagnostic] = []

        for element in powerElements {
            let address = HIDElementAddress(
                reportID: Int(IOHIDElementGetReportID(element)),
                page: Int(IOHIDElementGetUsagePage(element)),
                usage: Int(IOHIDElementGetUsage(element))
            )
            reportsByUsage[UsageKey(page: address.page, usage: address.usage), default: []]
                .insert(address.reportID)

            var value: Int64?
            if openResult == kIOReturnSuccess {
                let valuePointer = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
                if IOHIDDeviceGetValue(device, element, valuePointer) == kIOReturnSuccess {
                    value = Int64(IOHIDValueGetIntegerValue(valuePointer.pointee.takeUnretainedValue()))
                }
                valuePointer.deallocate()
            }
            if value != nil {
                readableAddresses.insert(address)
            }

            diagnostics.append(ElementDiagnostic(
                address: address,
                type: Int(IOHIDElementGetType(element).rawValue),
                value: value,
                logicalMin: IOHIDElementGetLogicalMin(element),
                logicalMax: IOHIDElementGetLogicalMax(element),
                unit: Int(IOHIDElementGetUnit(element)),
                exponent: Int(IOHIDElementGetUnitExponent(element))
            ))
        }

        if openResult == kIOReturnSuccess {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        return InspectedDevice(
            manufacturer: stringProperty(device, kIOHIDManufacturerKey) ?? "Unknown manufacturer",
            product: stringProperty(device, kIOHIDProductKey) ?? "Unknown UPS",
            vendorID: intProperty(device, kIOHIDVendorIDKey) ?? 0,
            productID: intProperty(device, kIOHIDProductIDKey) ?? 0,
            readableAddresses: readableAddresses,
            reportsByUsage: reportsByUsage,
            diagnostics: diagnostics
        )
    }

    private static func printDiagnostic(_ device: InspectedDevice) {
        print("Diagnostic report (serial number intentionally omitted):")
        print("page usage report type value logical_min logical_max unit exponent")
        for element in device.diagnostics.sorted(by: {
            ($0.address.page, $0.address.usage, $0.address.reportID, $0.type)
                < ($1.address.page, $1.address.usage, $1.address.reportID, $1.type)
        }) {
            print(String(
                format: "0x%04x 0x%04x %3d %4d %12@ %11ld %11ld 0x%08x %3d",
                element.address.page,
                element.address.usage,
                element.address.reportID,
                element.type,
                (element.value.map(String.init) ?? "unreadable") as NSString,
                element.logicalMin,
                element.logicalMax,
                element.unit,
                element.exponent
            ))
        }
    }

    private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func fail(_ message: String, code: Int32) -> Never {
        fputs("Compatibility check failed: \(message)\n", stderr)
        exit(code)
    }
}

private struct UsageKey: Hashable {
    let page: Int
    let usage: Int
}

private struct InspectedDevice {
    let manufacturer: String
    let product: String
    let vendorID: Int
    let productID: Int
    let readableAddresses: Set<HIDElementAddress>
    let reportsByUsage: [UsageKey: Set<Int>]
    let diagnostics: [ElementDiagnostic]

    func reportCount(page: Int, usage: Int) -> Int {
        reportsByUsage[UsageKey(page: page, usage: usage)]?.count ?? 0
    }
}

private struct ElementDiagnostic {
    let address: HIDElementAddress
    let type: Int
    let value: Int64?
    let logicalMin: Int
    let logicalMax: Int
    let unit: Int
    let exponent: Int
}
