import Foundation
import HealthKit

/// One workout read from Apple Health, with the calories Health recorded for it.
struct WorkoutSummary: Identifiable {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    /// Active energy (kcal) Apple Health attributes to this workout — the same
    /// "Active Calories" figure shown in the Fitness and Health apps.
    let activeCalories: Double
    /// Resting (basal) energy (kcal) burned during the workout. Added to active
    /// energy this gives the "Total Calories" figure shown in the Fitness app.
    let restingCalories: Double
    let sourceName: String

    var totalCalories: Double { activeCalories + restingCalories }

    func calories(_ mode: CalorieMode) -> Double {
        switch mode {
        case .active: activeCalories
        case .total: totalCalories
        }
    }
}

enum CalorieMode: String, CaseIterable, Identifiable {
    case active = "Active"
    case total = "Total"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "Active Calories"
        case .total: "Total Calories"
        }
    }

    var explanation: String {
        switch self {
        case .active: "Active calories recorded with each workout in Apple Health."
        case .total: "Active plus resting calories burned during each workout, from Apple Health."
        }
    }
}

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var workouts: [WorkoutSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    private let store = HKHealthStore()
    private var hasRequestedAuthorization = false

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
    ]

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func calories(for mode: CalorieMode) -> Double { workouts.reduce(0) { $0 + $1.calories(mode) } }
    var totalDuration: TimeInterval { workouts.reduce(0) { $0 + $1.duration } }

    /// Asks for read access the first time. iOS only shows the permission sheet once;
    /// afterwards the user changes access in Settings › Health › Data Access & Devices.
    func requestAuthorizationIfNeeded() async throws {
        guard !hasRequestedAuthorization else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        hasRequestedAuthorization = true
    }

    /// Loads every workout that started within [start, end).
    func loadWorkouts(from start: Date, to end: Date) async {
        guard isHealthDataAvailable else {
            errorMessage = "Apple Health isn't available on this device."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await requestAuthorizationIfNeeded()

            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
            )
            let results = try await descriptor.result(for: store)

            let resting = await restingCalories(for: results)
            let energyType = HKQuantityType(.activeEnergyBurned)
            workouts = results.enumerated().map { index, workout in
                let kcal = workout.statistics(for: energyType)?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0
                return WorkoutSummary(
                    id: workout.uuid,
                    activityType: workout.workoutActivityType,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    duration: workout.duration,
                    activeCalories: kcal,
                    restingCalories: resting[index],
                    sourceName: workout.sourceRevision.source.name
                )
            }
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Resting energy for each workout, in the same order. Uses the workout's own
    /// statistics when the recording app saved them (e.g. Apple Watch); otherwise sums
    /// the Resting Energy samples Health has for the workout's time span.
    private func restingCalories(for workouts: [HKWorkout]) async -> [Double] {
        let basalType = HKQuantityType(.basalEnergyBurned)
        return await withTaskGroup(of: (Int, Double).self) { group in
            for (index, workout) in workouts.enumerated() {
                if let kcal = workout.statistics(for: basalType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    group.addTask { (index, kcal) }
                } else {
                    let start = workout.startDate
                    let end = workout.endDate
                    group.addTask { [store] in
                        (index, await Self.basalCalories(in: store, from: start, to: end))
                    }
                }
            }
            var values = Array(repeating: 0.0, count: workouts.count)
            for await (index, kcal) in group {
                values[index] = kcal
            }
            return values
        }
    }

    /// Sum of Resting Energy between two dates. Samples that only partly overlap are
    /// prorated by HealthKit. Returns 0 when there's no data or access was denied.
    nonisolated private static func basalCalories(in store: HKHealthStore, from start: Date, to end: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.basalEnergyBurned), predicate: predicate),
            options: .cumulativeSum
        )
        let statistics = try? await descriptor.result(for: store)
        return statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }
}
