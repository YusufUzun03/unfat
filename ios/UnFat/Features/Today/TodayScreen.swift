import SwiftData
import SwiftUI

/// Today tab: calorie ring and macro bars, then today's entries oldest first.
/// Tap edits an entry, swipe deletes it, the context menu pins the food as a favorite.
struct TodayScreen: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @State private var editingEntry: FoodEntry?
    @State private var savedTick = 0
    @State private var isCopyConfirmationPresented = false
    @State private var actionFailed = false

    init() {
        var descriptor = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)])
        descriptor.fetchLimit = 300
        _entries = Query(descriptor)
    }

    private var todayEntries: [FoodEntry] {
        FoodLogService.entries(on: .now, from: entries)
    }

    private var yesterdayCount: Int {
        FoodLogService.entries(on: FoodLogService.yesterday(of: .now), from: entries).count
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let today = todayEntries
        let totals = FoodLogService.totals(of: today)
        NavigationStack {
            List {
                Section {
                    header(totals)
                }
                Section("Bugün yediklerin") {
                    if today.isEmpty {
                        emptyState
                    } else {
                        ForEach(today) { entry in
                            row(entry)
                        }
                    }
                }
            }
            .navigationTitle("Bugün")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry) {
                refreshWidgetSnapshot(context)
                savedTick += 1
            }
        }
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
        .sensoryFeedback(Haptics.foodLogged, trigger: savedTick)
    }

    // MARK: - Pieces

    private func header(_ totals: DayTotals) -> some View {
        HStack(spacing: Spacing.lg) {
            CalorieRing(value: totals.kcal, target: profile?.targetKcal ?? 0)
            VStack(spacing: Spacing.sm) {
                MacroBar(title: "Protein", eaten: totals.protein, target: profile?.targetProteinG ?? 0)
                MacroBar(title: "Karbonhidrat", eaten: totals.carbs, target: profile?.targetCarbsG ?? 0)
                MacroBar(title: "Yağ", eaten: totals.fat, target: profile?.targetFatG ?? 0)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private var emptyState: some View {
        Text("Henüz bir şey eklemedin.")
            .foregroundStyle(Palette.secondaryLabel)
        if yesterdayCount > 0 {
            Button("Dünü kopyala") {
                isCopyConfirmationPresented = true
            }
        }
    }

    private func row(_ entry: FoodEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            FoodEntryRow(
                time: entry.loggedAt,
                name: entry.name,
                detail: FoodFormat.entryDetail(entry),
                kcal: entry.kcal
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
        .contextMenu {
            if FoodLogService.isLoggableRef(entry.foodRef) {
                Button {
                    addFavorite(entry)
                } label: {
                    Label("Favorilere ekle", systemImage: "star")
                }
            }
        }
    }

    // MARK: - Actions

    private func delete(_ entry: FoodEntry) {
        do {
            try FoodLogService.delete(entry, in: context)
            refreshWidgetSnapshot(context)
        } catch {
            actionFailed = true
        }
    }

    private func addFavorite(_ entry: FoodEntry) {
        do {
            try FoodLogService.addFavorite(from: entry, in: context)
        } catch {
            actionFailed = true
        }
    }

    private func copyYesterday() {
        do {
            let copied = try FoodLogService.copyYesterday(in: context)
            if copied > 0 {
                refreshWidgetSnapshot(context)
                savedTick += 1
            }
        } catch {
            actionFailed = true
        }
    }
}
