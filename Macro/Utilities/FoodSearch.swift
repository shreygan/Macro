//
//  FoodSearch.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/9/26.
//

import Foundation

struct FoodSearch {
    private let tokens: [Token]
    private let compactQuery: String

    init(_ query: String) {
        let words = Self.words(in: query)
        tokens = words.map(Token.init)
        compactQuery = words.joined()
    }

    var isEmpty: Bool { tokens.isEmpty }

    func matches(_ food: FoodItem) -> Bool {
        relevance(of: food) != nil
    }

    func matches(name: String, fields: [String?]) -> Bool {
        relevance(name: name, fields: fields) != nil
    }

    func nameTier(of food: FoodItem) -> Int? {
        guard let relevance = relevance(of: food) else { return nil }
        if relevance.nameMatches == tokens.count { return 0 }
        return relevance.nameMatches > 0 ? 1 : 2
    }

    func ranked(
        _ foods: [FoodItem],
        stats: [UUID: FoodLogStats]
    ) -> [FoodItem] {
        foods
            .compactMap { food in relevance(of: food).map { (food, $0) } }
            .sorted { lhs, rhs in
                if lhs.1 < rhs.1 { return true }
                if rhs.1 < lhs.1 { return false }
                let lhsDate = stats[lhs.0.id]?.lastLogged ?? .distantPast
                let rhsDate = stats[rhs.0.id]?.lastLogged ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return lhs.0.dateAdded > rhs.0.dateAdded
            }
            .map(\.0)
    }

    struct SourceSplit {
        let name: String
        let source: String
    }

    static func sourceSplit(
        of query: String,
        sources: [String]
    ) -> SourceSplit? {
        let chunks = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard chunks.count > 1 else { return nil }
        let compactChunks = chunks.map { words(in: $0).joined() }

        let candidates =
            sources
            .map { (source: $0, compact: words(in: $0).joined()) }
            .filter { !$0.compact.isEmpty }
            .sorted { $0.compact.count > $1.compact.count }

        func name(from range: Range<Int>) -> String? {
            let kept = range.drop { compactChunks[$0].isEmpty }
                .reversed().drop { compactChunks[$0].isEmpty }.reversed()
            guard !kept.isEmpty else { return nil }
            return kept.map { chunks[$0] }.joined(separator: " ")
        }

        for candidate in candidates {
            for count in 1..<chunks.count {
                if compactChunks[..<count].joined() == candidate.compact,
                    let name = name(from: count..<chunks.count)
                {
                    return SourceSplit(name: name, source: candidate.source)
                }
                let start = chunks.count - count
                if compactChunks[start...].joined() == candidate.compact,
                    let name = name(from: 0..<start)
                {
                    return SourceSplit(name: name, source: candidate.source)
                }
            }
        }
        return nil
    }

    static func suggestion(for query: String, in foods: [FoodItem]) -> String? {
        suggestion(
            for: query,
            in: foods.map { (name: $0.name, fields: fields(of: $0)) }
        )
    }

    static func suggestion(
        for query: String,
        in items: [(name: String, fields: [String?])]
    ) -> String? {
        let queryWords = words(in: query)
        guard !queryWords.isEmpty else { return nil }

        let itemFields = items.map { item in
            ([item.name] + item.fields).compactMap { $0 }.map(Field.init)
        }
        let vocabulary = Set(itemFields.flatMap { $0.flatMap(\.words) })

        var corrected: [String] = []
        var changed = false
        for word in queryWords {
            let token = Token(word)
            let isKnown = itemFields.contains { fields in
                fields.contains { $0.quality(for: token) != nil }
            }
            if isKnown {
                corrected.append(word)
            } else if let fix = correction(for: word, in: vocabulary) {
                corrected.append(fix)
                changed = true
            } else {
                return nil
            }
        }
        guard changed else { return nil }

        let suggestion = corrected.joined(separator: " ")
        let search = FoodSearch(suggestion)
        guard
            items.contains(where: {
                search.matches(name: $0.name, fields: $0.fields)
            })
        else { return nil }
        return suggestion
    }

    private static func correction(
        for word: String,
        in vocabulary: Set<String>
    ) -> String? {
        let maxDistance = word.count >= 8 ? 2 : word.count >= 4 ? 1 : 0
        guard maxDistance > 0, let first = word.first else { return nil }

        var bestRank = (Int.max, Int.max)
        var fixes = Set<String>()
        for candidate in vocabulary where candidate.first == first {
            guard
                let match = closestMatch(
                    for: word,
                    in: candidate,
                    maxDistance: maxDistance
                )
            else { continue }

            let rank = (match.distance, match.isPrefix ? 1 : 0)
            if rank < bestRank {
                bestRank = rank
                fixes = [match.text]
            } else if rank == bestRank {
                fixes.insert(match.text)
            }
        }
        return fixes.count == 1 ? fixes.first : nil
    }

    private static func closestMatch(
        for word: String,
        in candidate: String,
        maxDistance: Int
    ) -> (text: String, distance: Int, isPrefix: Bool)? {
        let full = editDistance(word, candidate)
        if full <= maxDistance {
            return (candidate, full, false)
        }

        let letters = Array(candidate)
        let longest = min(letters.count - 1, word.count + maxDistance)
        let shortest = max(1, word.count - maxDistance)
        var best: (text: String, distance: Int)?
        for length in stride(from: longest, through: shortest, by: -1) {
            let prefix = String(letters[..<length])
            let distance = editDistance(word, prefix)
            if distance <= maxDistance, distance < (best?.distance ?? .max) {
                best = (prefix, distance)
            }
        }
        return best.map { ($0.text, $0.distance, true) }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }

        var table = Array(
            repeating: Array(repeating: 0, count: b.count + 1),
            count: a.count + 1
        )
        for i in 0...a.count { table[i][0] = i }
        for j in 0...b.count { table[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                table[i][j] = min(
                    table[i - 1][j] + 1,
                    table[i][j - 1] + 1,
                    table[i - 1][j - 1] + cost
                )
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    table[i][j] = min(table[i][j], table[i - 2][j - 2] + 1)
                }
            }
        }
        return table[a.count][b.count]
    }

    private struct Relevance: Comparable {
        var nameStartsWithQuery: Bool
        var score: Int
        var nameMatches: Int

        static func < (lhs: Relevance, rhs: Relevance) -> Bool {
            if lhs.nameStartsWithQuery != rhs.nameStartsWithQuery {
                return lhs.nameStartsWithQuery
            }
            return lhs.score < rhs.score
        }
    }

    private struct Field {
        let words: [String]
        let compact: String

        init(_ text: String) {
            words = FoodSearch.words(in: text)
            compact = words.joined()
        }

        func quality(for token: Token, isSecondary: Bool = false) -> Int? {
            let allowsPartial = !isSecondary || token.text.count >= 3

            if words.contains(where: { word in
                word == token.text || token.plurals.contains(word)
                    || (allowsPartial && word.hasPrefix(token.text))
            }) {
                return 0
            }
            if allowsPartial, token.text.count > 1,
                compact.contains(token.text)
                    || token.plurals.contains(where: { plural in
                        words.contains { $0.hasSuffix(plural) }
                    })
            {
                return 1
            }
            return nil
        }
    }

    private struct Token {
        let text: String
        let plurals: [String]

        init(_ text: String) {
            self.text = text
            plurals = FoodSearch.singulars(of: text)
        }
    }

    private static func fields(of food: FoodItem) -> [String?] {
        [
            food.source?.source,
            food.category?.category,
            food.foodGroup?.foodGroup,
            food.type.rawValue,
        ]
    }

    private func relevance(of food: FoodItem) -> Relevance? {
        relevance(name: food.name, fields: Self.fields(of: food))
    }

    private func relevance(name: String, fields: [String?]) -> Relevance? {
        guard !isEmpty else { return nil }

        let name = Field(name)
        let others = fields.compactMap { $0 }.map(Field.init)

        var score = 0
        var nameMatches = 0
        for token in tokens {
            if let quality = name.quality(for: token) {
                score += quality
                nameMatches += 1
            } else if let quality = others.compactMap({
                $0.quality(for: token, isSecondary: true)
            }).min() {
                score += 2 + quality
            } else {
                return nil
            }
        }

        return Relevance(
            nameStartsWithQuery: name.compact.hasPrefix(compactQuery),
            score: score,
            nameMatches: nameMatches
        )
    }

    private static func words(in text: String) -> [String] {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func singulars(of word: String) -> [String] {
        guard word.count > 3, word.hasSuffix("s") else { return [] }
        var result = [String(word.dropLast())]
        if word.hasSuffix("ies") {
            result.append(String(word.dropLast(3)) + "y")
        } else if word.hasSuffix("es") {
            result.append(String(word.dropLast(2)))
        }
        return result
    }
}
