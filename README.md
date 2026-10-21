# Workout Calories (iPhone)

A SwiftUI app that totals the calories burned in your workouts over a date
range you choose. All numbers come straight from Apple Health. For each
workout it uses the **Active Calories** Health stored with it, the same figure
the Fitness app shows.

## Features
- Pick **From / To** dates, or use Quick Select (Today, Last 7 Days, This Week,
  Last 30 Days, This Month, Last Month, This Year). The range covers whole days.
- Shows total kcal, workout count, total time and average per workout.
- Bar chart of calories by day, week or month, depending on range length.
- Breakdown by activity type (Running, Strength, Cycling, …).
- A list of each workout with its date, duration, source (Apple Watch, Strava, …) and kcal.
- Pull to refresh. It also refreshes when you return to the app.
- Read-only: it never writes to Apple Health.

## Requirements
- A Mac with Xcode 16 or newer
- An iPhone with iOS 17 or newer (HealthKit data isn't available in the Simulator in any useful way)
- An Apple ID signed in to Xcode (Xcode ▸ Settings ▸ Accounts)

## Run it on your iPhone
1. Copy this folder to your Mac and open `CalorieTracker.xcodeproj`.
2. Select the **CalorieTracker** target ▸ **Signing & Capabilities**:
   - Choose your **Team**.
   - Change **Bundle Identifier** to something unique, e.g. `com.yourname.WorkoutCalories`.
   - Check that **HealthKit** appears as a capability. It is already set up in
     `CalorieTracker.entitlements`. If Xcode asks, click "+ Capability" ▸ HealthKit.
3. Plug in your iPhone (or pair it over Wi‑Fi), pick it as the run destination, and press **Run**.
4. First launch on the phone: if iOS says the developer is untrusted, go to
   Settings ▸ General ▸ VPN & Device Management and trust your developer
   certificate. You may also need to turn on Settings ▸ Privacy & Security ▸ Developer Mode.
5. When the Health permission sheet appears, allow **Workouts** and **Active Energy**.

If the app shows no workouts, check Settings ▸ Health ▸ Data Access & Devices ▸
Workout Calories and make sure both permissions are on.

## Code layout
| File | Purpose |
|---|---|
| `CalorieTracker/HealthKitManager.swift` | HealthKit authorization, the workout query and per-workout active-energy totals |
| `CalorieTracker/ContentView.swift` | Date range UI, presets, summary, chart, breakdown and list |
| `CalorieTracker/WorkoutActivityType+Display.swift` | Names and SF Symbols for workout types |
| `CalorieTracker.entitlements` | HealthKit entitlement |
