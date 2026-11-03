#if DEBUG
import SwiftUI

/// Barcode screens reachable from `-UNFAT_SCREEN`. The simulator has no camera, so the scanner route
/// shows the no-camera state with manual entry.
enum BarcodeDebugScreen: Hashable, Sendable {
    case scanner
    case productCard
    case productPartial
    case productNotFound
}

/// Fixture products for the barcode routes.
enum BarcodeFixtures {
    static let barcode = "8690504021052"

    /// A Turkish wafer with full nutrients and a serving.
    static let fullProduct = OFFProduct(
        barcode: barcode,
        name: "Ülker Çikolatalı Gofret",
        brand: "Ülker",
        kcalPer100g: 520,
        proteinPer100g: 6.5,
        carbsPer100g: 62,
        fatPer100g: 26,
        fiberPer100g: 2.1,
        servingText: "36 g",
        servingGrams: 36,
        imageURLString: nil
    )

    /// Name known, no kcal and only some macros.
    static let partialProduct = OFFProduct(
        barcode: "8690632012345",
        name: "Ev Yapımı Kurabiye",
        brand: nil,
        kcalPer100g: nil,
        proteinPer100g: 7,
        carbsPer100g: nil,
        fatPer100g: nil,
        fiberPer100g: nil,
        servingText: nil,
        servingGrams: nil,
        imageURLString: nil
    )
}

struct BarcodeDebugView: View {
    let kind: BarcodeDebugScreen

    var body: some View {
        NavigationStack {
            switch kind {
            case .scanner:
                BarcodeScannerView(onBarcode: { _ in }, forcedAccess: .unavailable)
            case .productCard:
                card(.product(BarcodeFixtures.fullProduct))
            case .productPartial:
                card(.product(BarcodeFixtures.partialProduct))
            case .productNotFound:
                card(.notFound(barcode: "8690000000017"))
            }
        }
    }

    private func card(_ state: ProductCardState) -> some View {
        ProductCardView(
            state: state,
            onAdd: { _ in },
            onCreateCustom: { _ in },
            onRetry: { _ in },
            onScanAgain: {}
        )
    }
}
#endif
