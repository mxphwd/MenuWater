import Foundation
import Observation
import ServiceManagement

enum VolumeUnit: String, CaseIterable, Identifiable {
    case milliliters
    case ounces

    var id: Self { self }

    var symbol: String {
        switch self {
        case .milliliters: "ml"
        case .ounces: "oz"
        }
    }
}

@MainActor
@Observable
final class HydrationModel {
    private enum Keys {
        static let count = "hydration.count"
        static let date = "hydration.date"
        static let interval = "reminder.interval"
        static let volumeML = "container.volumeML"
        static let unit = "container.unit"
    }

    var count: Int
    var intervalMinutes: Int
    var volumeML: Double
    var volumeUnit: VolumeUnit
    var launchAtLogin: Bool
    var errorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let reminderPresenter = ReminderPresenter()
    @ObservationIgnored private var reminderTimer: Timer?
    @ObservationIgnored private var midnightTimer: Timer?

    let intervalOptions = [15, 30, 45, 60, 90, 120]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        count = defaults.integer(forKey: Keys.count)
        intervalMinutes = defaults.object(forKey: Keys.interval) as? Int ?? 60
        volumeML = defaults.object(forKey: Keys.volumeML) as? Double ?? 350
        volumeUnit = VolumeUnit(rawValue: defaults.string(forKey: Keys.unit) ?? "") ?? .milliliters
        launchAtLogin = SMAppService.mainApp.status == .enabled

        resetIfNeeded()
        scheduleMidnightReset()
        scheduleReminder()
    }

    var totalML: Double {
        Double(count) * volumeML
    }

    var displayedContainerVolume: Double {
        switch volumeUnit {
        case .milliliters:
            volumeML
        case .ounces:
            volumeML / 29.5735
        }
    }

    var displayedTotal: Double {
        switch volumeUnit {
        case .milliliters:
            totalML
        case .ounces:
            totalML / 29.5735
        }
    }

    func addContainer() {
        resetIfNeeded()
        count += 1
        saveCount()
    }

    func removeContainer() {
        resetIfNeeded()
        count = max(0, count - 1)
        saveCount()
    }

    func updateInterval(_ minutes: Int) {
        intervalMinutes = minutes
        defaults.set(minutes, forKey: Keys.interval)
        scheduleReminder()
    }

    func updateVolume(_ displayedValue: Double) {
        switch volumeUnit {
        case .milliliters:
            volumeML = displayedValue
        case .ounces:
            volumeML = displayedValue * 29.5735
        }
        defaults.set(volumeML, forKey: Keys.volumeML)
    }

    func updateUnit(_ unit: VolumeUnit) {
        volumeUnit = unit
        defaults.set(unit.rawValue, forKey: Keys.unit)
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = String(localized: "Couldn’t update the launch-at-login setting.")
        }
    }

    func refreshForToday() {
        resetIfNeeded()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func showReminderNow() {
        reminderPresenter.show()
    }

    private func resetIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        let savedDate = defaults.object(forKey: Keys.date) as? Date

        guard savedDate.map({ !Calendar.current.isDate($0, inSameDayAs: today) }) ?? true else {
            return
        }

        count = 0
        saveCount()
    }

    private func saveCount() {
        defaults.set(count, forKey: Keys.count)
        defaults.set(Calendar.current.startOfDay(for: .now), forKey: Keys.date)
    }

    private func scheduleReminder() {
        reminderTimer?.invalidate()

        let timer = Timer(
            timeInterval: TimeInterval(intervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reminderPresenter.show()
            }
        }

        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func scheduleMidnightReset() {
        midnightTimer?.invalidate()

        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) else {
            return
        }

        midnightTimer = Timer(fire: nextMidnight, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resetIfNeeded()
                self?.scheduleMidnightReset()
            }
        }

        if let midnightTimer {
            RunLoop.main.add(midnightTimer, forMode: .common)
        }
    }
}
