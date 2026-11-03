import Foundation

/// Built-in program templates, built from bundled seed exercise ids (`ex-0001`...).
/// Names are stored on the created `Program`, so they are plain Turkish data strings.
struct ProgramTemplate: Identifiable, Sendable {
    struct Entry: Sendable {
        let exerciseID: String
        let sets: Int
        let repMin: Int
        let repMax: Int
        let restSeconds: Int
    }

    struct Day: Sendable {
        let name: String
        let exercises: [Entry]
    }

    let id: String
    let name: String
    let days: [Day]

    var dayCount: Int { days.count }
}

extension ProgramTemplate {
    // Rep schemes: heavy compound, standard, and light isolation work.
    private static func heavy(_ id: String) -> Entry {
        Entry(exerciseID: id, sets: 3, repMin: 6, repMax: 8, restSeconds: 120)
    }

    private static func standard(_ id: String) -> Entry {
        Entry(exerciseID: id, sets: 3, repMin: 8, repMax: 12, restSeconds: 90)
    }

    private static func light(_ id: String) -> Entry {
        Entry(exerciseID: id, sets: 3, repMin: 12, repMax: 15, restSeconds: 60)
    }

    static let fullBody = ProgramTemplate(id: "full-body-3", name: "Full body", days: [
        Day(name: "A Günü", exercises: [
            heavy("ex-0121"), heavy("ex-0001"), standard("ex-0032"), standard("ex-0058"), light("ex-0174"),
        ]),
        Day(name: "B Günü", exercises: [
            heavy("ex-0027"), standard("ex-0006"), standard("ex-0047"), light("ex-0067"), light("ex-0083"),
        ]),
        Day(name: "C Günü", exercises: [
            standard("ex-0133"), standard("ex-0005"), standard("ex-0037"), standard("ex-0150"), light("ex-0101"),
        ]),
    ])

    static let upperLower = ProgramTemplate(id: "upper-lower-4", name: "Üst/Alt", days: [
        Day(name: "Üst A", exercises: [
            heavy("ex-0001"), heavy("ex-0032"), standard("ex-0058"), standard("ex-0047"), light("ex-0083"), light("ex-0101"),
        ]),
        Day(name: "Alt A", exercises: [
            heavy("ex-0121"), heavy("ex-0027"), standard("ex-0133"), light("ex-0145"), light("ex-0159"),
        ]),
        Day(name: "Üst B", exercises: [
            heavy("ex-0006"), standard("ex-0037"), standard("ex-0061"), light("ex-0067"), light("ex-0088"), light("ex-0105"),
        ]),
        Day(name: "Alt B", exercises: [
            standard("ex-0150"), standard("ex-0140"), standard("ex-0134"), light("ex-0146"), light("ex-0160"),
        ]),
    ])

    static let pushPullLegs = ProgramTemplate(id: "ppl-6", name: "İtme/Çekme/Bacak", days: [
        Day(name: "İtme A", exercises: [
            heavy("ex-0001"), standard("ex-0058"), standard("ex-0006"), light("ex-0067"), light("ex-0101"), light("ex-0105"),
        ]),
        Day(name: "Çekme A", exercises: [
            heavy("ex-0032"), standard("ex-0047"), standard("ex-0037"), light("ex-0076"), light("ex-0083"), light("ex-0088"),
        ]),
        Day(name: "Bacak A", exercises: [
            heavy("ex-0121"), heavy("ex-0027"), standard("ex-0133"), light("ex-0134"), light("ex-0145"), light("ex-0159"),
        ]),
        Day(name: "İtme B", exercises: [
            heavy("ex-0005"), standard("ex-0061"), standard("ex-0012"), light("ex-0067"), light("ex-0104"), light("ex-0111"),
        ]),
        Day(name: "Çekme B", exercises: [
            heavy("ex-0042"), standard("ex-0033"), standard("ex-0037"), light("ex-0073"), light("ex-0086"), light("ex-0088"),
        ]),
        Day(name: "Bacak B", exercises: [
            standard("ex-0150"), standard("ex-0140"), standard("ex-0134"), light("ex-0146"), light("ex-0160"), light("ex-0172"),
        ]),
    ])

    static let all: [ProgramTemplate] = [fullBody, upperLower, pushPullLegs]
}
