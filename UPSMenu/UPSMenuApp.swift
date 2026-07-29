import AppKit
import SwiftUI

@main
@MainActor
struct UPSMenuApp: App {
    @StateObject private var monitor = UPSMonitor()
    @AppStorage("visibleMetricIDs") private var visibleMetricIDs = UPSMetric.defaultVisibleIDs
    @AppStorage("menuBarMetricID") private var menuBarMetricID = UPSMetric.estimatedPower.rawValue

    var body: some Scene {
        MenuBarExtra {
            UPSStatusView(
                reading: monitor.reading,
                errorMessage: monitor.errorMessage,
                visibleMetricIDs: $visibleMetricIDs,
                menuBarMetricID: $menuBarMetricID
            )
        } label: {
            HStack(spacing: 4) {
                Image(systemName: monitor.menuSymbol)
                Text(menuBarTitle)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        guard let reading = monitor.reading,
              let metric = UPSMetric(rawValue: menuBarMetricID) else {
            return "UPS"
        }
        return metric.menuBarValue(for: reading) ?? "UPS"
    }
}

private struct UPSStatusView: View {
    let reading: UPSReading?
    let errorMessage: String?
    @Binding var visibleMetricIDs: String
    @Binding var menuBarMetricID: String

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let reading {
                    statusContent(reading)
                } else {
                    unavailableContent
                }
            }

            Divider()

            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit UPS Menu", systemImage: "power")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)

                Spacer()

                Text(versionText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 292)
        .padding(16)
    }

    private func statusContent(_ reading: UPSReading) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: reading.isOnline ? "bolt.shield.fill" : "battery.50percent")
                    .font(.title2)
                    .foregroundStyle(reading.isOnline ? .green : .orange)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 1) {
                    Text(reading.model)
                        .font(.headline)
                    Text(reading.isOnline ? "Online" : "On Battery")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                configurationMenu
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(UPSMetric.visibleMetrics(from: visibleMetricIDs)) { metric in
                    if let value = metric.value(for: reading) {
                        metricRow(metric.title, value: value, symbol: metric.symbol)
                    }
                }
            }

            Text("Updated \(reading.measuredAt, style: .time)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var configurationMenu: some View {
        Menu {
            Section("Menu Bar") {
                Picker("Displayed Value", selection: $menuBarMetricID) {
                    ForEach(UPSMetric.menuBarChoices) { metric in
                        Label(metric.title, systemImage: metric.symbol)
                            .tag(metric.rawValue)
                    }
                }
            }

            Section("Window") {
                ForEach(UPSMetric.allCases) { metric in
                    Toggle(isOn: visibilityBinding(for: metric)) {
                        Label(metric.title, systemImage: metric.symbol)
                    }
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .help("Customize UPS information")
    }

    private var unavailableContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text("UPS Unavailable")
                    .font(.headline)
                Text(errorMessage ?? "No data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func metricRow(_ label: String, value: String, symbol: String) -> some View {
        GridRow {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func visibilityBinding(for metric: UPSMetric) -> Binding<Bool> {
        Binding {
            UPSMetric.visibleMetrics(from: visibleMetricIDs).contains(metric)
        } set: { isVisible in
            var selected = Set(visibleMetricIDs.split(separator: ",").map(String.init))
            if isVisible {
                selected.insert(metric.rawValue)
            } else {
                selected.remove(metric.rawValue)
            }
            visibleMetricIDs = UPSMetric.allCases
                .filter { selected.contains($0.rawValue) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "-"
        return "Version \(version) (\(build))"
    }
}
