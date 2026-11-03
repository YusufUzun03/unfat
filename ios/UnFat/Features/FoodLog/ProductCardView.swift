import SwiftUI

/// What the product screen shows after a scan or manual barcode entry.
enum ProductCardState: Equatable {
    case loading(barcode: String)
    case product(OFFProduct)
    case notFound(barcode: String)
    /// Offline, timeout or an unusable answer.
    case failed(barcode: String)
}

/// Result of a barcode lookup: the product with per-100 g values, serving, ODbL attribution and the
/// "Ekle" action; or a loading, incomplete, not-found or error state.
struct ProductCardView: View {
    let state: ProductCardState
    /// Opens the amount editor for a complete product.
    let onAdd: (OFFProduct) -> Void
    /// Opens the custom food form (prefilled with the barcode and whatever is known).
    let onCreateCustom: (CustomFoodDraft) -> Void
    let onRetry: (String) -> Void
    let onScanAgain: () -> Void

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Ürün aranıyor")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .product(let product):
                productContent(product)
            case .notFound(let barcode):
                notFoundContent(barcode)
            case .failed(let barcode):
                failedContent(barcode)
            }
        }
        .background(Palette.groupedBackground)
        .navigationTitle("Ürün")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Product

    private func productContent(_ product: OFFProduct) -> some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                header(product)
                if let kcal = product.kcalPer100g {
                    energy(kcal)
                    macros(product)
                    if product.servingGrams != nil || product.servingText != nil {
                        servingRow(product)
                    }
                } else {
                    incompleteNote
                }
                attribution
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar {
                if product.hasEnergy {
                    PrimaryActionButton(title: "Ekle") { onAdd(product) }
                } else {
                    PrimaryActionButton(title: "Düzenleyerek ekle") {
                        onCreateCustom(CustomFoodDraft(product: product))
                    }
                }
            }
        }
    }

    private func header(_ product: OFFProduct) -> some View {
        VStack(spacing: Spacing.xxs) {
            if let name = product.name {
                Text(name)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            } else {
                Text("Adsız ürün")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.secondaryLabel)
            }
            if let brand = product.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Text(verbatim: product.barcode)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Palette.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func energy(_ kcal: Double) -> some View {
        VStack(spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(verbatim: FoodFormat.number(kcal))
                    .font(.heroNumber)
                    .monospacedDigit()
                Text("kcal")
                    .font(.title3)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Text("100 g başına")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func macros(_ product: OFFProduct) -> some View {
        HStack(spacing: Spacing.md) {
            macro("Protein", product.proteinPer100g)
            macro("Karbonhidrat", product.carbsPer100g)
            macro("Yağ", product.fatPer100g)
        }
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity)
    }

    private func macro(_ title: LocalizedStringKey, _ value: Double?) -> some View {
        VStack(spacing: Spacing.xxs) {
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: FoodFormat.number(value, fractionDigits: 0...1))
                    Text("g")
                }
                .font(.rowNumber)
                .monospacedDigit()
            } else {
                Text(verbatim: "–")
                    .font(.rowNumber)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func servingRow(_ product: OFFProduct) -> some View {
        EditorCard {
            LabeledContent("Porsiyon") {
                if let grams = product.servingGrams {
                    Text(verbatim: "\(FoodFormat.number(grams, fractionDigits: 0...1)) g")
                        .monospacedDigit()
                } else if let text = product.servingText {
                    Text(verbatim: text)
                }
            }
            .frame(minHeight: 44)
        }
    }

    private var incompleteNote: some View {
        VStack(spacing: Spacing.xs) {
            Text("Besin değerleri eksik")
                .font(.headline)
            Text("Bu ürünün kalori bilgisi Open Food Facts'te yok. Değerleri kendin girerek ekleyebilirsin.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private var attribution: some View {
        Text("Veri: Open Food Facts (ODbL)")
            .font(.footnote)
            .foregroundStyle(Palette.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xs)
    }

    // MARK: - Not found and error

    private func notFoundContent(_ barcode: String) -> some View {
        ContentUnavailableView {
            Label("Bu ürün bulunamadı", systemImage: "barcode")
        } description: {
            Text("Barkod: \(barcode)")
                .monospacedDigit()
        } actions: {
            Button("Özel yemek olarak ekle") {
                onCreateCustom(CustomFoodDraft(barcode: barcode))
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            Button("Tekrar tara", action: onScanAgain)
                .tint(Palette.accent)
        }
    }

    private func failedContent(_ barcode: String) -> some View {
        ContentUnavailableView {
            Label("Bağlantı kurulamadı", systemImage: "wifi.slash")
        } description: {
            Text("İnternet bağlantını kontrol edip tekrar dene.")
        } actions: {
            Button("Tekrar dene") { onRetry(barcode) }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
            Button("Tekrar tara", action: onScanAgain)
                .tint(Palette.accent)
        }
    }

    private func bottomBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.vertical, Spacing.sm)
            .background(.bar)
    }
}
