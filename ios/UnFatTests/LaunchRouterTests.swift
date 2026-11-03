import Testing
@testable import UnFat

#if DEBUG
@Test func launchRouterParsesScreenArgument() {
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN", "workout"]) == .workout)
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN"]) == nil)
    #expect(LaunchRouter.route(arguments: ["UnFat"]) == nil)
}
#endif
