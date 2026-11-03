import Testing
@testable import UnFatCore

@Test func coreVersionIsSet() {
    #expect(coreVersion() == "0.1.0")
}
