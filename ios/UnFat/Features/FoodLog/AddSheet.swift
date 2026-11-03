import SwiftData
import SwiftUI

/// Screens pushed inside the add sheet.
enum AddRoute: Hashable {
    case food(LoggableFood)
    case quickKcal
    case customFood
}

/// The global add sheet: action rows, recents and favorites, and food search. A food opens the
/// amount editor; saving writes the entry, refreshes the widget snapshot, tells the owner
/// (`onLogged`, which plays the success haptic from a view that outlives the sheet) and dismisses.
struct AddSheet: View {
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodEntry]
    @Query private var favorites: [FavoriteFood]
    @Query private var customFoods: [CustomFood]
    @State private var path: [AddRoute] = []
    @State private var searchText: String
    @State private var detent: PresentationDetent = .large
    @State private var isCopyConfirmationPresented = false
    @State private var actionFailed = false

    init(initialSearch: String = "", onLogged: @escaping () -> Void = {}) {
        self.onLogged = onLogged
        _searchText = State(initialValue: initialSearch)
        var descriptor = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)])
        descriptor.fetchLimit = 300
        _entries = Query(descriptor)
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedSearch.isEmpty }

    private var searchResults: [LoggableFood] {
        FoodLogService.search(trimmedSearch, customFoods: customFoods)
    }

    private var recents: [LoggableFood] {
        FoodLogService.recentFoods(from: entries, customFoods: customFoods)
    }

    private var favoriteFoods: [LoggableFood] {
        FoodLogService.favoriteFoods(favorites, entries: entries, customFoods: customFoods)
    }

    private var yesterdayCount: Int {
        FoodLogService.entries(on: FoodLogService.yesterday(of: .now), from: entries).count
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if isSearching {
                    searchSection
                } else {
                    browseSections
                }
            }
            .overlay {
                if isSearching && searchResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedSearch)
                }
            }
            .navigationTitle("Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Yemek ara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: AddRoute.self) { route in
                destination(for: route)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .confirmationDialog("Dünü kopyala", isPresented: $isCopyConfirmationPresented, titleVisibility: .visible) {
            Button("Kopyala", action: copyYesterday)
        } message: {
            Text("Dünkü \(yesterdayCount) kayıt bugüne eklenecek.")
        }
        .alert("Kaydedilemedi", isPresented: $actionFailed) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bilgilerin kaydedilirken bir hata oluştu. Tekrar dene.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var browseSections: some View {
        Section {
            NavigationLink(value: AddRoute.quickKcal) {
                AddActionLabel(title: "Hızlı kcal", systemImage: "bolt")
            }
            NavigationLink(value: AddRoute.customFood) {
                AddActionLabel(title: "Özel yemek", systemImage: "square.and.pencil")
            }
            Button {
                isCopyConfirmationPresented = true
            } label: {
                AddActionLabel(title: "Dünü kopyala", systemImage: "doc.on.doc")
            }
            .disabled(yesterdayCount == 0)
        }

        let recentFoods = recents
        if !recentFoods.isEmpty {
            Section("Son eklenenler") {
                ForEach(recentFoods) { food in
                    NavigationLink(value: AddRoute.food(food)) {
                        FoodChoiceRow(food: food)
                    }
                }
            }
        }

        let pinned = favoriteFoods
        if !pinned.isEmpty {
            Section("Favoriler") {
                ForEach(pinned) { food in
                    NavigationLink(value: AddRoute.food(food)) {
                        FoodChoiceRow(food: food)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        let results = searchResults
        if !results.isEmpty {
            Section {
                ForEach(results) { food in
                    NavigationLink(value: AddRoute.food(food)) {
                        FoodChoiceRow(food: food)
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destination(for route: AddRoute) -> some View {
        switch route {
        case .food(let food):
            EntryEditorView(food: food, onSaved: finish)
        case .quickKcal:
            QuickKcalView(onSaved: finish)
        case .customFood:
            CustomFoodForm { food in
                // Replace the form with the amount editor, so back returns to the add list.
                path = [.food(LoggableFood(custom: food))]
            }
        }
    }

    // MARK: - Actions

    private func finish() {
        refreshWidgetSnapshot(context)
        onLogged()
        dismiss()
    }

    private func copyYesterday() {
        do {
            let copied = try FoodLogService.copyYesterday(in: context)
            if copied > 0 { finish() }
        } catch {
            actionFailed = true
        }
    }
}
