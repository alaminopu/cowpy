import Foundation

/// Matching rules for the search panel.
nonisolated enum SearchFilter {
    /// Every whitespace-separated term must appear somewhere in the text,
    /// ignoring case, accents and width — so "cafe moo" finds "Moo at the Café".
    static func matches(_ query: String, in text: String) -> Bool {
        let terms = terms(in: query)
        guard !terms.isEmpty else { return true }
        let haystack = normalise(text)
        return terms.allSatisfy(haystack.contains)
    }

    static func terms(in query: String) -> [String] {
        normalise(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func normalise(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
