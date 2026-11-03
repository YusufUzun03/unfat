import SwiftUI

/// Placeholder for the global add sheet (search, recents, barcode, photo) built in task 7.
struct AddSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {}
                .navigationTitle("Ekle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
        }
    }
}
