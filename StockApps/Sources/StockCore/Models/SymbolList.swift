import Foundation

public extension String {
    /// Splits on commas, spaces and newlines, upper-cases and de-duplicates (keeping order).
    var symbolList: [String] {
        var seen = Set<String>()
        return components(separatedBy: CharacterSet(charactersIn: ", \n\t;"))
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
