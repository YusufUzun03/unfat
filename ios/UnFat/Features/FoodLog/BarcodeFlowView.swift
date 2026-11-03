import SwiftData
import SwiftUI

/// The barcode screen of the add sheet: scanner, then the lookup result in place of it.
/// A known food goes to `onFood` (the amount editor); a missing or incomplete product goes to
/// `onCustom` with a prefilled draft.
struct BarcodeFlowView: View {
    let onFood: (LoggableFood) -> Void
    let onCustom: (CustomFoodDraft) -> Void
    var service = BarcodeLookupService()

    @Environment(\.modelContext) private var context
    @State private var phase: Phase = .scanning
    @State private var lookupTask: Task<Void, Never>?

    private enum Phase: Equatable {
        case scanning
        case result(ProductCardState)
    }

    var body: some View {
        Group {
            switch phase {
            case .scanning:
                BarcodeScannerView(onBarcode: lookup)
            case .result(let state):
                ProductCardView(
                    state: state,
                    onAdd: add,
                    onCreateCustom: onCustom,
                    onRetry: lookup,
                    onScanAgain: { phase = .scanning }
                )
            }
        }
        .onDisappear { lookupTask?.cancel() }
    }

    private func lookup(_ barcode: String) {
        lookupTask?.cancel()
        phase = .result(.loading(barcode: barcode))
        lookupTask = Task {
            do {
                let outcome = try await service.lookup(barcode, in: context)
                guard !Task.isCancelled else { return }
                switch outcome {
                case .customFood(let food):
                    onFood(food)
                case .product(let product):
                    phase = .result(.product(product))
                case .notFound(let code):
                    phase = .result(.notFound(barcode: code))
                }
            } catch is CancellationError {
                // The screen went away or a newer lookup started.
            } catch {
                guard !Task.isCancelled else { return }
                phase = .result(.failed(barcode: barcode))
            }
        }
    }

    private func add(_ product: OFFProduct) {
        if let food = LoggableFood(product: product) {
            onFood(food)
        } else {
            onCustom(CustomFoodDraft(product: product))
        }
    }
}
