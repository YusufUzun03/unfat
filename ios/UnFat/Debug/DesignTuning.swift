#if DEBUG
import Observation

/// Live-editable design values for the DEBUG tuning panel. Views read the result through
/// `\.designValues`; Release builds never create this and use `DesignValues.standard`.
@MainActor
@Observable
final class DesignTuning {
    var springDuration = DesignValues.standard.springDuration
    var springBounce = DesignValues.standard.springBounce
    var ringSpringDuration = DesignValues.standard.ringSpringDuration
    var ringSpringBounce = DesignValues.standard.ringSpringBounce
    var ringStroke = DesignValues.standard.ringStroke

    var values: DesignValues {
        DesignValues(
            springDuration: springDuration,
            springBounce: springBounce,
            ringSpringDuration: ringSpringDuration,
            ringSpringBounce: ringSpringBounce,
            ringStroke: ringStroke
        )
    }

    func reset() {
        let standard = DesignValues.standard
        springDuration = standard.springDuration
        springBounce = standard.springBounce
        ringSpringDuration = standard.ringSpringDuration
        ringSpringBounce = standard.ringSpringBounce
        ringStroke = standard.ringStroke
    }
}
#endif
