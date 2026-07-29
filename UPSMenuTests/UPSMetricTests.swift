import Testing
@testable import UPS_Menu

struct UPSMetricTests {
    @Test func formatsWindowAndMenuBarValues() {
        let reading = makeReading()

        #expect(UPSMetric.estimatedPower.value(for: reading) == "54.0 W")
        #expect(UPSMetric.estimatedPower.menuBarValue(for: reading) == "54.0 W")
        #expect(UPSMetric.runtime.menuBarValue(for: reading) == "47 min")
        #expect(UPSMetric.transferRange.value(for: reading) == "170-260 V")
        #expect(UPSMetric.batteryState.value(for: reading) == "Fully Charged")
        #expect(UPSMetric.powerCondition.value(for: reading) == "Normal")
    }

    @Test func decodesVisibleMetricPreferencesInDisplayOrder() {
        let metrics = UPSMetric.visibleMetrics(from: "runtime,load,not-a-metric")

        #expect(metrics == [.load, .runtime])
    }

    @Test func omitsUnsupportedOptionalMetrics() {
        let reading = makeReading(
            nominalVoltage: nil,
            lowTransferVoltage: nil,
            highTransferVoltage: nil,
            isCharging: nil,
            isDischarging: nil,
            isFullyCharged: nil,
            isBatteryLow: nil,
            isOverloaded: nil,
            isBoosting: nil
        )

        #expect(UPSMetric.nominalVoltage.value(for: reading) == nil)
        #expect(UPSMetric.transferRange.value(for: reading) == nil)
        #expect(UPSMetric.batteryState.value(for: reading) == nil)
        #expect(UPSMetric.powerCondition.value(for: reading) == nil)
    }

    @Test func recognizesTheValidatedCyberPowerProfile() {
        let profile = UPSDeviceProfile.matching(vendorID: 0x0764, productID: 0x0501)

        #expect(profile?.name == "CyberPower CP900EPFCLCD")
        #expect(profile?.requiredTelemetry.count == 7)
        #expect(UPSDeviceProfile.matching(vendorID: 0xffff, productID: 0xffff) == nil)
    }

    private func makeReading(
        nominalVoltage: Int? = 230,
        lowTransferVoltage: Int? = 170,
        highTransferVoltage: Int? = 260,
        isCharging: Bool? = false,
        isDischarging: Bool? = false,
        isFullyCharged: Bool? = true,
        isBatteryLow: Bool? = false,
        isOverloaded: Bool? = false,
        isBoosting: Bool? = false
    ) -> UPSReading {
        UPSReading(
            model: "CP900EPFCLCD",
            isOnline: true,
            batteryCharge: 100,
            runtimeSeconds: 2_850,
            inputVoltage: 237,
            outputVoltage: 237,
            loadPercent: 10,
            nominalWatts: 540,
            nominalVoltage: nominalVoltage,
            lowTransferVoltage: lowTransferVoltage,
            highTransferVoltage: highTransferVoltage,
            isCharging: isCharging,
            isDischarging: isDischarging,
            isFullyCharged: isFullyCharged,
            isBatteryLow: isBatteryLow,
            isOverloaded: isOverloaded,
            isBoosting: isBoosting,
            measuredAt: .now
        )
    }
}