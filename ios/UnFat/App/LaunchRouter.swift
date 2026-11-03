#if DEBUG
import Foundation

/// Where a launch route lands: a tab of the root `TabView`, or a full-screen DEBUG screen.
enum LaunchDestination: Hashable, Sendable {
    case tab(AppTab)
    case screen(DebugScreen)
}

/// Screens reachable with the `-UNFAT_SCREEN <name>` launch argument (CI screenshots job).
/// Raw values are the names used on the command line; append new screens here.
enum LaunchRoute: String, CaseIterable, Sendable {
    case today
    case workout
    case progress
    case add
    case todayEmpty = "today-empty"
    case todayOver = "today-over"
    case addSearch = "add-search"
    case entryEditor = "entry-editor"
    case quickKcal = "quick-kcal"
    case customFood = "custom-food"
    case barcodeScanner = "barcode-scanner"
    case productCard = "product-card"
    case productPartial = "product-partial"
    case productNotFound = "product-not-found"
    /// Design-system gallery, from the top (rings, macro bars).
    case gallery
    /// Gallery from the number roll section (numbers, chips, keypad).
    case gallery2 = "gallery-2"
    /// Gallery from the rest timer section (rest timer, rows).
    case gallery3 = "gallery-3"
    /// Gallery with the tuning panel open.
    case galleryTuning = "gallery-tuning"
    /// Widget views at real size (small, medium, circular) in normal, over and no-target states.
    case galleryWidgets = "gallery-widgets"
    /// Workout Live Activity views (Lock Screen banner, Dynamic Island) in resting, idle and rest-over states.
    case galleryLiveActivity = "gallery-live-activity"
    case onboardingSex = "onboarding-sex"
    case onboardingBody = "onboarding-body"
    case onboardingWeight = "onboarding-weight"
    case onboardingActivity = "onboarding-activity"
    case onboardingGoal = "onboarding-goal"
    case onboardingTargets = "onboarding-targets"
    case onboardingPermissions = "onboarding-permissions"
    case goalEditor = "goal-editor"
    case workoutEmpty = "workout-empty"
    case programEditor = "program-editor"
    case exercisePicker = "exercise-picker"
    case session
    case sessionSummary = "session-summary"
    case progress90 = "progress-90"
    case progressEmpty = "progress-empty"
    case weightEntry = "weight-entry"
    case exerciseProgress = "exercise-progress"

    var destination: LaunchDestination {
        switch self {
        case .today: .tab(.today)
        case .workout: .tab(.workout)
        case .progress: .tab(.progress)
        case .add: .tab(.add)
        case .todayEmpty: .screen(.foodLog(.todayEmpty))
        case .todayOver: .screen(.foodLog(.todayOver))
        case .addSearch: .screen(.foodLog(.addSearch))
        case .entryEditor: .screen(.foodLog(.entryEditor))
        case .quickKcal: .screen(.foodLog(.quickKcal))
        case .customFood: .screen(.foodLog(.customFood))
        case .barcodeScanner: .screen(.barcode(.scanner))
        case .productCard: .screen(.barcode(.productCard))
        case .productPartial: .screen(.barcode(.productPartial))
        case .productNotFound: .screen(.barcode(.productNotFound))
        case .gallery: .screen(.gallery(firstSection: .ring, showsTuning: false))
        case .gallery2: .screen(.gallery(firstSection: .numbers, showsTuning: false))
        case .gallery3: .screen(.gallery(firstSection: .restTimer, showsTuning: false))
        case .galleryTuning: .screen(.gallery(firstSection: .ring, showsTuning: true))
        case .galleryWidgets: .screen(.widgetGallery)
        case .galleryLiveActivity: .screen(.liveActivityGallery)
        case .onboardingSex: .screen(.onboarding(.sex))
        case .onboardingBody: .screen(.onboarding(.body))
        case .onboardingWeight: .screen(.onboarding(.weight))
        case .onboardingActivity: .screen(.onboarding(.activity))
        case .onboardingGoal: .screen(.onboarding(.goal))
        case .onboardingTargets: .screen(.onboarding(.targets))
        case .onboardingPermissions: .screen(.onboarding(.permissions))
        case .goalEditor: .screen(.goalEditor)
        case .workoutEmpty: .screen(.workout(.empty))
        case .programEditor: .screen(.workout(.programEditor))
        case .exercisePicker: .screen(.workout(.exercisePicker))
        case .session: .screen(.workout(.session))
        case .sessionSummary: .screen(.workout(.sessionSummary))
        case .progress90: .screen(.progress(.range90))
        case .progressEmpty: .screen(.progress(.empty))
        case .weightEntry: .screen(.progress(.weightEntry))
        case .exerciseProgress: .screen(.progress(.exercise))
        }
    }
}

enum LaunchRouter {
    static let argument = "-UNFAT_SCREEN"

    /// Returns the route named after `-UNFAT_SCREEN`, or nil when absent or unknown.
    static func route(arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchRoute? {
        guard let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1)
        else { return nil }
        return LaunchRoute(rawValue: arguments[index + 1])
    }
}
#endif
