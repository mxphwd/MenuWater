import AppKit
import SwiftUI

struct ContentView: View {
    let model: HydrationModel

    var body: some View {
        VStack(spacing: 16) {
            HydrationSummary(
                count: model.count,
                total: model.displayedTotal,
                unit: model.volumeUnit,
                onRemove: model.removeContainer,
                onAdd: model.addContainer
            )

            Divider()

            ReminderControls(
                intervalMinutes: model.intervalMinutes,
                intervalOptions: model.intervalOptions,
                launchAtLogin: model.launchAtLogin,
                onIntervalChange: model.updateInterval,
                onLaunchAtLoginChange: model.updateLaunchAtLogin
            )

            ContainerSettings(
                displayedVolume: model.displayedContainerVolume,
                unit: model.volumeUnit,
                onVolumeChange: model.updateVolume,
                onUnitChange: model.updateUnit,
                onTryNow: model.showReminderNow
            )

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Quit Water Reminder") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            model.refreshForToday()
        }
    }
}

private struct HydrationSummary: View {
    let count: Int
    let total: Double
    let unit: VolumeUnit
    let onRemove: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.title)
                .foregroundStyle(.blue)

            Text(total, format: .number.precision(.fractionLength(unit == .milliliters ? 0 : 1)))
                .font(.system(.title, design: .rounded, weight: .semibold))
                .contentTransition(.numericText())

            Text(unit.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                }
                .disabled(count == 0)
                .accessibilityLabel("Remove one container")

                Text("\(count)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 28)
                    .accessibilityLabel("\(count) containers today")

                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Add one container")
            }
            .controlSize(.large)
        }
    }
}

private struct ReminderControls: View {
    let intervalMinutes: Int
    let intervalOptions: [Int]
    let launchAtLogin: Bool
    let onIntervalChange: (Int) -> Void
    let onLaunchAtLoginChange: (Bool) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Picker(
                "Remind me",
                selection: Binding(
                    get: { intervalMinutes },
                    set: onIntervalChange
                )
            ) {
                ForEach(intervalOptions, id: \.self) { minutes in
                    Text(intervalLabel(minutes))
                        .tag(minutes)
                }
            }

            Toggle(
                "Start at login",
                isOn: Binding(
                    get: { launchAtLogin },
                    set: onLaunchAtLoginChange
                )
            )
        }
    }

    private func intervalLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes) min")
        }

        let hours = Double(minutes) / 60
        return String(localized: "\(hours, format: .number.precision(.fractionLength(hours.rounded() == hours ? 0 : 1))) hr")
    }
}

private struct ContainerSettings: View {
    let displayedVolume: Double
    let unit: VolumeUnit
    let onVolumeChange: (Double) -> Void
    let onUnitChange: (VolumeUnit) -> Void
    let onTryNow: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                Label("Container size", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            if isExpanded {
                HStack {
                    Stepper(
                        value: Binding(
                            get: { displayedVolume },
                            set: onVolumeChange
                        ),
                        in: volumeRange,
                        step: volumeStep
                    ) {
                        Text(displayedVolume, format: .number.precision(.fractionLength(unit == .milliliters ? 0 : 1)))
                            .monospacedDigit()
                    }

                    Picker(
                        "Unit",
                        selection: Binding(
                            get: { unit },
                            set: onUnitChange
                        )
                    ) {
                        ForEach(VolumeUnit.allCases) { unit in
                            Text(unit.symbol)
                                .tag(unit)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

#if DEBUG
            Button("Try now", action: onTryNow)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
#endif
        }
    }

    private var volumeRange: ClosedRange<Double> {
        switch unit {
        case .milliliters: 50...2_000
        case .ounces: 2...68
        }
    }

    private var volumeStep: Double {
        unit == .milliliters ? 50 : 1
    }
}

#Preview {
    ContentView(model: HydrationModel(defaults: UserDefaults(suiteName: "Preview")!))
}
