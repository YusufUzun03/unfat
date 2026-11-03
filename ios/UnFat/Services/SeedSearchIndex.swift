import Foundation

/// Text folding for search keys and queries: Turkish-aware lowercasing, then diacritic removal,
/// then punctuation collapsed to single spaces.
/// "İskender", "ISKENDER", "ıskender" -> "iskender"; "Mercimek Çorbası" -> "mercimek corbasi".
enum SearchFolding {
    private static let turkishLocale = Locale(identifier: "tr_TR")

    static func fold(_ text: String) -> String {
        // Turkish letters are mapped explicitly: dotless ı has no Unicode decomposition, and
        // locale-independent lowercasing turns İ into "i̇" (i + combining dot).
        var mapped = ""
        mapped.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "İ", "I", "ı": mapped.append("i")
            case "Ç", "ç": mapped.append("c")
            case "Ğ", "ğ": mapped.append("g")
            case "Ö", "ö": mapped.append("o")
            case "Ş", "ş": mapped.append("s")
            case "Ü", "ü": mapped.append("u")
            default: mapped.append(character)
            }
        }
        let lowered = mapped.lowercased(with: turkishLocale)
        let stripped = lowered.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)

        var result = ""
        result.reserveCapacity(stripped.utf8.count)
        var pendingSpace = false
        for scalar in stripped.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingSpace, !result.isEmpty {
                    result.append(" ")
                }
                pendingSpace = false
                result.unicodeScalars.append(scalar)
            } else {
                pendingSpace = true
            }
        }
        return result
    }

    static func words(_ folded: String) -> [String] {
        folded.split(separator: " ").map(String.init)
    }
}

/// Name + aliases of one searchable item, in display form (folded by the index).
struct SearchableText: Sendable, Hashable {
    var name: String
    var aliases: [String]

    init(name: String, aliases: [String] = []) {
        self.name = name
        self.aliases = aliases
    }
}

/// In-memory search over item names and aliases. Keys are folded once at init.
/// Ranking: exact name > name prefix > every query word prefixes a name word > alias match
/// (exact, prefix or word prefix) > substring of name or alias. Ties: shorter name, then
/// alphabetical (folded), then original order.
struct SeedSearchIndex: Sendable {
    enum MatchRank: Int, Comparable, Sendable {
        case exactName = 0
        case namePrefix
        case wordPrefix
        case alias
        case substring

        static func < (lhs: MatchRank, rhs: MatchRank) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    struct Entry: Sendable {
        let name: String
        let nameWords: [String]
        let nameLength: Int
        let aliases: [String]
        let aliasWords: [[String]]

        init(_ text: SearchableText) {
            name = SearchFolding.fold(text.name)
            nameWords = SearchFolding.words(name)
            nameLength = name.count
            aliases = text.aliases.map(SearchFolding.fold).filter { !$0.isEmpty }
            aliasWords = aliases.map(SearchFolding.words)
        }
    }

    private let entries: [Entry]

    init(_ items: [SearchableText]) {
        entries = items.map(Entry.init)
    }

    var count: Int { entries.count }

    /// Positions (indices into the array given at init) of matching items, best first.
    func search(_ query: String, limit: Int? = nil) -> [Int] {
        let folded = SearchFolding.fold(query)
        guard !folded.isEmpty else { return [] }
        let queryWords = SearchFolding.words(folded)

        var hits: [(position: Int, rank: MatchRank)] = []
        for (position, entry) in entries.enumerated() {
            if let rank = Self.rank(entry, query: folded, queryWords: queryWords) {
                hits.append((position, rank))
            }
        }
        hits.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            let left = entries[lhs.position]
            let right = entries[rhs.position]
            if left.nameLength != right.nameLength { return left.nameLength < right.nameLength }
            if left.name != right.name { return left.name < right.name }
            return lhs.position < rhs.position
        }
        let positions = hits.map(\.position)
        if let limit { return Array(positions.prefix(max(0, limit))) }
        return positions
    }

    /// Rank of the item at `position` for `query`, or nil when it does not match.
    func rank(at position: Int, for query: String) -> MatchRank? {
        guard entries.indices.contains(position) else { return nil }
        let folded = SearchFolding.fold(query)
        guard !folded.isEmpty else { return nil }
        return Self.rank(entries[position], query: folded, queryWords: SearchFolding.words(folded))
    }

    private static func rank(_ entry: Entry, query: String, queryWords: [String]) -> MatchRank? {
        if entry.name == query { return .exactName }
        if entry.name.hasPrefix(query) { return .namePrefix }
        if wordsArePrefixed(entry.nameWords, by: queryWords) { return .wordPrefix }
        for (alias, words) in zip(entry.aliases, entry.aliasWords) {
            if alias.hasPrefix(query) || wordsArePrefixed(words, by: queryWords) {
                return .alias
            }
        }
        if entry.name.contains(query) || entry.aliases.contains(where: { $0.contains(query) }) {
            return .substring
        }
        return nil
    }

    /// true when every query word is a prefix of at least one of `words`.
    private static func wordsArePrefixed(_ words: [String], by queryWords: [String]) -> Bool {
        guard !queryWords.isEmpty else { return false }
        return queryWords.allSatisfy { queryWord in
            words.contains { $0.hasPrefix(queryWord) }
        }
    }
}
