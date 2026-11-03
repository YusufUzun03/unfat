import Foundation

/// Workout energy and strength estimates (data-and-science.md §3.6, §3.7).
public enum Workout {
    /// Highest rep count for which an e1RM is reported (SPEC: Epley, reps <= 10 shown).
    public static let maxRepsForEstimate = 10

    /// Net MET calories: `(MET - 1) × 3.5 × kg / 200 × minutes`.
    ///
    /// Net of resting burn to avoid double counting with TDEE (§3.6). Clamped, not
    /// rejected: MET <= 1, non-positive weight or minutes, or non-finite input give 0.
    public static func metKcal(met: Double, weightKg: Double, minutes: Double) -> Double {
        guard met.isFinite, weightKg.isFinite, minutes.isFinite,
              met > 1, weightKg > 0, minutes > 0 else { return 0 }
        return (met - 1) * 3.5 * weightKg / 200 * minutes
    }

    /// Epley estimated 1RM: `w × (1 + r / 30)`; `r == 1` returns `w` exactly.
    ///
    /// Returns nil for reps outside 1...10 or a non-positive / non-finite weight.
    public static func epleyOneRepMax(weightKg: Double, reps: Int) -> Double? {
        guard weightKg.isFinite, weightKg > 0, (1...maxRepsForEstimate).contains(reps) else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }
}

/// One completed working set.
public struct SetRecord: Sendable, Hashable, Codable {
    /// Stable exercise identifier (e.g. the exercise UUID string or seed id).
    public let exerciseID: String
    public let date: Date
    public let weightKg: Double
    public let reps: Int

    public init(exerciseID: String, date: Date, weightKg: Double, reps: Int) {
        self.exerciseID = exerciseID
        self.date = date
        self.weightKg = weightKg
        self.reps = reps
    }

    /// Epley e1RM of this set, nil when reps are outside 1...10.
    public var estimatedOneRepMax: Double? {
        Workout.epleyOneRepMax(weightKg: weightKg, reps: reps)
    }
}

public enum PRKind: String, Sendable, Hashable, CaseIterable, Codable {
    /// Best Epley e1RM (only sets with 1...10 reps count).
    case estimatedOneRepMax
    /// Heaviest weight lifted for at least one rep.
    case maxWeight
}

public struct PersonalRecord: Sendable, Hashable, Codable {
    public let exerciseID: String
    public let kind: PRKind
    /// New record value, kg.
    public let valueKg: Double
    /// Previous best from history, kg.
    public let previousBestKg: Double
    /// The set that produced the record.
    public let set: SetRecord
}

/// Personal-record detection per exercise (SPEC: PR detection per exercise).
///
/// Decided here (spec silent):
/// - A PR needs a strictly greater value than the best in `history` for that exercise.
/// - An exercise with no valid history yields no PR (first session establishes the baseline,
///   so a first workout does not flood the user with records).
/// - At most one PR per (exercise, kind) is returned: the best new value; ties within the
///   new sets go to the earliest set in input order.
/// - Sets with reps < 1 or non-positive / non-finite weight are ignored everywhere.
/// - Output is sorted by exercise ID, then kind (e1RM before max weight) for stable display.
public enum PersonalRecords {
    public static func detect(newSets: [SetRecord], history: [SetRecord]) -> [PersonalRecord] {
        let historyByExercise = Dictionary(grouping: history.filter(isValid), by: \.exerciseID)
        let newByExercise = Dictionary(grouping: newSets.filter(isValid), by: \.exerciseID)

        var records: [PersonalRecord] = []
        for exerciseID in newByExercise.keys.sorted() {
            guard let past = historyByExercise[exerciseID], let sets = newByExercise[exerciseID] else { continue }
            for kind in PRKind.allCases {
                guard let previous = past.compactMap({ value(of: $0, kind: kind) }).max(),
                      let best = bestSet(in: sets, kind: kind),
                      best.value > previous else { continue }
                records.append(PersonalRecord(exerciseID: exerciseID, kind: kind,
                                              valueKg: best.value, previousBestKg: previous, set: best.set))
            }
        }
        return records
    }

    static func value(of set: SetRecord, kind: PRKind) -> Double? {
        switch kind {
        case .estimatedOneRepMax: return set.estimatedOneRepMax
        case .maxWeight: return set.weightKg
        }
    }

    private static func bestSet(in sets: [SetRecord], kind: PRKind) -> (set: SetRecord, value: Double)? {
        var best: (set: SetRecord, value: Double)?
        for set in sets {
            guard let candidate = value(of: set, kind: kind) else { continue }
            if best == nil || candidate > best!.value { best = (set, candidate) }
        }
        return best
    }

    private static func isValid(_ set: SetRecord) -> Bool {
        set.reps >= 1 && set.weightKg.isFinite && set.weightKg > 0
    }
}
