import Foundation

struct FuzzyMatchResult: Sendable {
    let app: AppItem
    let score: Double
    let matchedRanges: [Range<String.Index>]
}

struct FuzzyMatcher {
    /// Returns matched apps sorted by relevance (highest score first).
    func match(query: String, in apps: [AppItem]) -> [FuzzyMatchResult] {
        guard !query.isEmpty else { return [] }

        let loweredQuery = query.lowercased()

        return apps.compactMap { app in
            let name = app.name
            let loweredName = name.lowercased()

            // Exact prefix match (highest priority)
            if loweredName.hasPrefix(loweredQuery) {
                let range = name.startIndex..<name.index(name.startIndex, offsetBy: query.count)
                return FuzzyMatchResult(app: app, score: 100, matchedRanges: [range])
            }

            // Substring match
            if let range = loweredName.range(of: loweredQuery) {
                let nameRange = name.index(name.startIndex, offsetBy: loweredName.distance(from: loweredName.startIndex, to: range.lowerBound))
                    ..< name.index(name.startIndex, offsetBy: loweredName.distance(from: loweredName.startIndex, to: range.upperBound))
                let positionBonus = range.lowerBound == loweredName.startIndex ? 20.0 : 0.0
                return FuzzyMatchResult(app: app, score: 80 + positionBonus, matchedRanges: [nameRange])
            }

            // Abbreviation match: "vsc" matches "Visual Studio Code"
            if let ranges = abbreviationMatch(query: loweredQuery, in: name) {
                return FuzzyMatchResult(app: app, score: 60, matchedRanges: ranges)
            }

            // Bundle ID contains query
            if app.bundleIdentifier.lowercased().contains(loweredQuery) {
                return FuzzyMatchResult(app: app, score: 40, matchedRanges: [])
            }

            // Levenshtein distance for short queries (typo tolerance)
            if loweredQuery.count >= 3 && loweredQuery.count <= 8 {
                let distance = levenshteinDistance(loweredQuery, String(loweredName.prefix(loweredQuery.count + 2)))
                if distance <= 2 {
                    let score = 30.0 - Double(distance) * 10.0
                    return FuzzyMatchResult(app: app, score: score, matchedRanges: [])
                }
            }

            return nil
        }
        .sorted { $0.score > $1.score }
    }

    // MARK: - Private

    private func abbreviationMatch(query: String, in name: String) -> [Range<String.Index>]? {
        let words = name.split(separator: " ")
        guard words.count >= query.count else { return nil }

        let initials = words.compactMap { $0.first }.map { Character(String($0).lowercased()) }
        let queryChars = Array(query.lowercased())

        guard queryChars.count <= initials.count else { return nil }

        for i in 0..<queryChars.count {
            if queryChars[i] != initials[i] { return nil }
        }

        // Build ranges for matched initial characters
        var ranges: [Range<String.Index>] = []
        var searchStart = name.startIndex
        for word in words.prefix(queryChars.count) {
            if let wordRange = name.range(of: String(word), range: searchStart..<name.endIndex) {
                let charRange = wordRange.lowerBound..<name.index(wordRange.lowerBound, offsetBy: 1)
                ranges.append(charRange)
                searchStart = wordRange.upperBound
            }
        }

        return ranges.isEmpty ? nil : ranges
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[m][n]
    }
}
