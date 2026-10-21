import SwiftUI

struct FilterSidebar: View {
    @Environment(ScreenerModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Universe") {
                Picker("Universe", selection: $model.universe) {
                    ForEach(Universe.allCases) { universe in
                        Label(universe.title, systemImage: universe.systemImage).tag(universe)
                    }
                }
                .labelsHidden()

                if model.universe == .custom {
                    TextField("Symbols", text: $model.watchlistText, prompt: Text("AAPL, MSFT, …"), axis: .vertical)
                        .lineLimit(3...8)
                        .labelsHidden()
                    Text("Separate symbols with commas or spaces. Use Yahoo symbols, e.g. BRK-B, SHOP.TO, ^GSPC.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Menu("Load a Preset Screen") {
                    ForEach(ScreenCriteria.presets) { preset in
                        Button(preset.name) { model.apply(preset: preset.criteria) }
                    }
                }
                Button("Clear All Filters", role: .destructive) { model.clearFilters() }
                    .disabled(model.criteria.activeCount == 0)
            } header: {
                HStack {
                    Text("Filters")
                    Spacer()
                    if model.criteria.activeCount > 0 {
                        Text("\(model.criteria.activeCount) active")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Trend") {
                ForEach(TrendCheck.allCases) { check in
                    Toggle(check.title, isOn: Binding(
                        get: { model.criteria.trends.contains(check) },
                        set: { isOn in
                            if isOn {
                                model.criteria.trends.insert(check)
                            } else {
                                model.criteria.trends.remove(check)
                            }
                        }
                    ))
                }
            }

            ForEach(Metric.Group.allCases, id: \.self) { group in
                Section {
                    ForEach(Metric.allCases.filter { $0.group == group }) { metric in
                        RangeFilterRow(metric: metric, filter: $model.criteria[metric])
                    }
                } header: {
                    Text(group.rawValue)
                } footer: {
                    if group == .fundamental && !model.fundamentalsAvailable {
                        Text("Yahoo didn't return fundamentals on the last refresh, so these filters will match nothing. Try Refresh again later.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct RangeFilterRow: View {
    let metric: Metric
    @Binding var filter: RangeFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(metric.title, isOn: $filter.enabled)
                .help(metric.help)
            if filter.enabled {
                HStack(spacing: 6) {
                    TextField("Min", value: $filter.min, format: .number, prompt: Text("Min"))
                        .labelsHidden()
                    Text("to")
                        .foregroundStyle(.secondary)
                    TextField("Max", value: $filter.max, format: .number, prompt: Text("Max"))
                        .labelsHidden()
                    if !metric.unit.isEmpty {
                        Text(metric.unit)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 14, alignment: .leading)
                    }
                }
                .textFieldStyle(.roundedBorder)
                Text(metric.help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
