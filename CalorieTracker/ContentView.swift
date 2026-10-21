import Charts
import HealthKit
import SwiftUI

struct ContentView: View {
    @StateObject private var health = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State private var endDate = Date.now

    private let calendar = Calendar.current

    /// The whole days covered by the pickers: midnight of the start day up to midnight after the end day.
    private var period: Period {
        let start = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return Period(start: start, end: end)
    }

    private var isValidPeriod: Bool { period.start < period.end }

    var body: some View {
        NavigationStack {
            List {
                periodSection

                if !health.isHealthDataAvailable {
                    messageSection("Apple Health isn't available on this device.", symbol: "heart.slash")
                } else if !isValidPeriod {
                    messageSection("The start date must be on or before the end date.", symbol: "calendar.badge.exclamationmark")
                } else if let error = health.errorMessage {
                    messageSection(error, symbol: "exclamationmark.triangle")
                } else if health.hasLoaded {
                    summarySection
                    if health.workouts.isEmpty {
                        emptySection
                    } else {
                        chartSection
                        activitySection
                        workoutsSection
                    }
                }
            }
            .navigationTitle("Workout Calories")
            .overlay {
                if health.isLoading && !health.hasLoaded {
                    ProgressView("Reading Apple Health…")
                }
            }
            .refreshable { await reload() }
            .task(id: period) { await reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reload() } }
            }
        }
    }

    private func reload() async {
        guard isValidPeriod else { return }
        await health.loadWorkouts(from: period.start, to: period.end)
    }

    // MARK: - Sections

    private var periodSection: some View {
        Section {
            DatePicker("From", selection: $startDate, in: ...Date.now, displayedComponents: .date)
            DatePicker("To", selection: $endDate, in: ...Date.now, displayedComponents: .date)
            Menu {
                ForEach(Preset.allCases) { preset in
                    Button(preset.rawValue) {
                        let range = preset.range(now: .now, calendar: calendar)
                        startDate = range.start
                        endDate = range.end
                    }
                }
            } label: {
                Label("Quick Select", systemImage: "calendar")
            }
        } header: {
            Text("Time Period")
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calories Burned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(health.totalCalories, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(period.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            LabeledContent("Workouts", value: health.workouts.count, format: .number)
            LabeledContent("Total Time", value: formatDuration(health.totalDuration))
            if !health.workouts.isEmpty {
                LabeledContent("Average per Workout") {
                    Text("\(health.totalCalories / Double(health.workouts.count), format: .number.precision(.fractionLength(0))) kcal")
                }
            }
        } footer: {
            Text("Active calories recorded with each workout in Apple Health.")
        }
    }

    private var chartSection: some View {
        let unit = period.chartUnit(calendar: calendar)
        return Section("Calories by \(unit.label)") {
            Chart(health.workouts) { workout in
                BarMark(
                    x: .value("Date", workout.startDate, unit: unit.component),
                    y: .value("kcal", workout.activeCalories)
                )
                .foregroundStyle(.orange.gradient)
            }
            .chartXScale(domain: period.start...period.end)
            .frame(height: 180)
            .padding(.vertical, 8)
        }
    }

    private var activitySection: some View {
        let groups = Dictionary(grouping: health.workouts, by: \.activityType.rawValue)
            .map { ActivityTotal(workouts: $0.value) }
            .sorted { $0.calories > $1.calories }

        return Section("By Activity") {
            ForEach(groups) { group in
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text(group.type.displayName)
                            Text("^[\(group.count) workout](inflect: true)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: group.type.symbolName)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text("\(group.calories, format: .number.precision(.fractionLength(0))) kcal")
                        .monospacedDigit()
                }
            }
        }
    }

    private var workoutsSection: some View {
        Section("Workouts") {
            ForEach(health.workouts) { workout in
                WorkoutRow(workout: workout)
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No workouts in this period")
                    .font(.headline)
                Text("If you expected workouts here, make sure this app can read Workouts and Active Energy in Settings › Health › Data Access & Devices.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private func messageSection(_ message: String, symbol: String) -> some View {
        Section {
            Label(message, systemImage: symbol)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Supporting views & types

private struct WorkoutRow: View {
    let workout: WorkoutSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.activityType.symbolName)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityType.displayName)
                    .font(.headline)
                Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(formatDuration(workout.duration)) · \(workout.sourceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(workout.activeCalories, format: .number.precision(.fractionLength(0)))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ActivityTotal: Identifiable {
    let type: HKWorkoutActivityType
    let count: Int
    let calories: Double
    var id: UInt { type.rawValue }

    init(workouts: [WorkoutSummary]) {
        type = workouts[0].activityType
        count = workouts.count
        calories = workouts.reduce(0) { $0 + $1.activeCalories }
    }
}

private struct Period: Equatable {
    let start: Date
    let end: Date

    var label: String {
        let lastDay = end.addingTimeInterval(-1)
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day().year()
        if Calendar.current.isDate(start, inSameDayAs: lastDay) {
            return start.formatted(format)
        }
        return "\(start.formatted(format)) – \(lastDay.formatted(format))"
    }

    func chartUnit(calendar: Calendar) -> (component: Calendar.Component, label: String) {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        switch days {
        case ...62: return (.day, "Day")
        case ...366: return (.weekOfYear, "Week")
        default: return (.month, "Month")
        }
    }
}

private enum Preset: String, CaseIterable, Identifiable {
    case today = "Today"
    case last7 = "Last 7 Days"
    case thisWeek = "This Week"
    case last30 = "Last 30 Days"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"

    var id: String { rawValue }

    /// Inclusive first and last day of the preset.
    func range(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        func startOf(_ component: Calendar.Component, _ date: Date) -> Date {
            calendar.dateInterval(of: component, for: date)?.start ?? date
        }
        switch self {
        case .today:
            return (now, now)
        case .last7:
            return (calendar.date(byAdding: .day, value: -6, to: now) ?? now, now)
        case .thisWeek:
            return (startOf(.weekOfYear, now), now)
        case .last30:
            return (calendar.date(byAdding: .day, value: -29, to: now) ?? now, now)
        case .thisMonth:
            return (startOf(.month, now), now)
        case .lastMonth:
            let thisMonth = startOf(.month, now)
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth
            let end = calendar.date(byAdding: .day, value: -1, to: thisMonth) ?? thisMonth
            return (start, end)
        case .thisYear:
            return (startOf(.year, now), now)
        }
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
}

#Preview {
    ContentView()
}
