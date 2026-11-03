import Testing
@testable import UnFatCore

@Test func massConversion() {
    // 100 / 0.45359237 = 220.462262...
    #expect(approx(Units.pounds(fromKg: 100), 220.4622622, tolerance: 1e-6))
    // 150 * 0.45359237 = 68.0388555
    #expect(approx(Units.kg(fromPounds: 150), 68.0388555))
    #expect(approx(Units.kg(fromPounds: Units.pounds(fromKg: 72.3)), 72.3))
}

@Test func lengthConversion() {
    // 180 / 2.54 = 70.8661417 in = 5 ft 10.8661417 in
    let fi = Units.feetAndInches(fromCm: 180)
    #expect(fi.feet == 5)
    #expect(approx(fi.inches, 10.8661417, tolerance: 1e-6))
    // rounded: 70.866 -> 71 in = 5 ft 11 in
    let rounded = Units.feetAndRoundedInches(fromCm: 180)
    #expect(rounded.feet == 5 && rounded.inches == 11)
    // 182.6 cm = 71.89 in -> 72 in = 6 ft 0 in (carry, never "5 ft 12 in")
    let carry = Units.feetAndRoundedInches(fromCm: 182.6)
    #expect(carry.feet == 6 && carry.inches == 0)
    // 5 ft 11 in = 71 in * 2.54 = 180.34 cm
    #expect(approx(Units.cm(feet: 5, inches: 11), 180.34))
    let negative = Units.feetAndInches(fromCm: -10)
    #expect(negative.feet == 0 && negative.inches == 0)
}

@Test func energyConversion() {
    // 1000 * 4.184 = 4184
    #expect(approx(Units.kJ(fromKcal: 1000), 4184))
    #expect(approx(Units.kcal(fromKJ: 4184), 1000))
}

@Test func displayRounding() {
    #expect(DisplayRounding.kcal(2209.5) == 2210)
    #expect(DisplayRounding.kcal(2209.4) == 2209)
    #expect(DisplayRounding.kcal(-0.5) == -1) // half away from zero
    #expect(DisplayRounding.kcal(.nan) == 0)
    #expect(DisplayRounding.grams(66.27) == 66)
    #expect(DisplayRounding.grams(66.5) == 67)
    #expect(DisplayRounding.oneDecimal(79.99) == 80.0)
    #expect(DisplayRounding.oneDecimal(80.149) == 80.1)
}
