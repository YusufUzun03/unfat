/// Unit conversions. Internal storage is always metric (kg, cm, kcal).
public enum Units {
    /// Exact international avoirdupois pound.
    public static let kgPerPound: Double = 0.45359237
    public static let cmPerInch: Double = 2.54
    public static let inchesPerFoot: Double = 12
    /// Thermochemical calorie.
    public static let kJPerKcal: Double = 4.184

    public static func pounds(fromKg kg: Double) -> Double { kg / kgPerPound }
    public static func kg(fromPounds lb: Double) -> Double { lb * kgPerPound }

    public static func inches(fromCm cm: Double) -> Double { cm / cmPerInch }
    public static func cm(fromInches inches: Double) -> Double { inches * cmPerInch }

    /// Splits a length into whole feet and remaining (fractional) inches.
    /// Negative input is treated as 0. Rounding the inches for display is the caller's job;
    /// use `feetAndRoundedInches` to avoid a "5 ft 12 in" result.
    public static func feetAndInches(fromCm cm: Double) -> (feet: Int, inches: Double) {
        let total = max(0, inches(fromCm: cm))
        let feet = (total / inchesPerFoot).rounded(.down)
        return (Int(feet), total - feet * inchesPerFoot)
    }

    /// Feet and whole inches, rounded to the nearest inch with carry into feet.
    public static func feetAndRoundedInches(fromCm cm: Double) -> (feet: Int, inches: Int) {
        let total = Int(max(0, inches(fromCm: cm)).rounded())
        return (total / 12, total % 12)
    }

    public static func cm(feet: Int, inches: Double) -> Double {
        cm(fromInches: Double(feet) * inchesPerFoot + inches)
    }

    public static func kJ(fromKcal kcal: Double) -> Double { kcal * kJPerKcal }
    public static func kcal(fromKJ kJ: Double) -> Double { kJ / kJPerKcal }
}

/// Display rounding rules (chosen here; §3 is silent). All use schoolbook rounding,
/// half away from zero. Store and compute unrounded values; round only for display.
/// - kcal: whole number.
/// - macro grams (targets and logged totals): whole grams.
/// - body weight, kg/lb and per-100 g nutrient values: one decimal.
public enum DisplayRounding {
    public static func kcal(_ value: Double) -> Int { toInt(value) }
    public static func grams(_ value: Double) -> Int { toInt(value) }

    public static func oneDecimal(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (value * 10).rounded() / 10
    }

    /// Non-finite values display as 0; values beyond `Int` range saturate.
    private static func toInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let rounded = value.rounded()
        if rounded >= Double(Int.max) { return Int.max }
        if rounded <= Double(Int.min) { return Int.min }
        return Int(rounded)
    }
}
