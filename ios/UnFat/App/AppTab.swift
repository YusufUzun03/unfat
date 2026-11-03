/// Top-level tabs. `add` is the search-role tab that opens the add sheet instead of showing content.
enum AppTab: Hashable, Sendable {
    case today
    case workout
    case progress
    case add
}
