import Testing
@testable import UnFat

#if DEBUG
@Test func launchRouterParsesScreenArgument() {
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN", "workout"]) == .workout)
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN", "gallery-2"]) == .gallery2)
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN", "nope"]) == nil)
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN"]) == nil)
    #expect(LaunchRouter.route(arguments: ["UnFat"]) == nil)
}

@Test func launchRoutesMapToTabsAndScreens() {
    #expect(LaunchRoute.today.destination == .tab(.today))
    #expect(LaunchRoute.workout.destination == .tab(.workout))
    #expect(LaunchRoute.progress.destination == .tab(.progress))
    #expect(LaunchRoute.add.destination == .tab(.add))
    #expect(LaunchRoute.gallery.destination == .screen(.gallery(firstSection: .ring, showsTuning: false)))
    #expect(LaunchRoute.galleryTuning.destination == .screen(.gallery(firstSection: .ring, showsTuning: true)))
}

@Test func galleryPagesStartAtDistinctSections() {
    let starts: [GallerySection] = [LaunchRoute.gallery, .gallery2, .gallery3].compactMap { route in
        if case .screen(.gallery(let first, _)) = route.destination { return first }
        return nil
    }
    #expect(starts == [.ring, .numbers, .restTimer])
}
#endif
