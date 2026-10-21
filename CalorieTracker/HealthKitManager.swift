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
    let sourceName: String
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
    ]

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var totalCalories: Double { workouts.reduce(0) { $0 + $1.activeCalories } }
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

            let energyType = HKQuantityType(.activeEnergyBurned)
            workouts = results.map { workout in
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
                    sourceName: workout.sourceRevision.source.name
                )
            }
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
