import SwiftUI

private let bundle = Bundle.module

public struct BookTableView: View {
    @ObservedObject var viewModel: LibraryViewModel

    public var body: some View {
        Table(viewModel.books, selection: $viewModel.selectedBookId) {
            TableColumn(NSLocalizedString("library.column.title", bundle: bundle, comment: "")) { entry in
                Text(entry.book.title)
            }
            .width(min: 150)

            TableColumn(NSLocalizedString("library.column.author", bundle: bundle, comment: "")) { entry in
                Text(entry.authorNames)
            }
            .width(min: 120)

            TableColumn(NSLocalizedString("library.column.year", bundle: bundle, comment: "")) { entry in
                Text(entry.book.year.map(String.init) ?? "—")
            }
            .width(60)

            TableColumn(NSLocalizedString("library.column.format", bundle: bundle, comment: "")) { entry in
                Text(entry.book.format.rawValue.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.1)))
            }
            .width(70)

            TableColumn(NSLocalizedString("library.column.genre", bundle: bundle, comment: "")) { entry in
                Text(entry.book.genre ?? "—")
            }
            .width(min: 80)
        }
        .contextMenu(forSelectionType: BookEntry.ID.self) { ids in
            if let id = ids.first, let entry = viewModel.books.first(where: { $0.id == id }) {
                Button(NSLocalizedString("library.edit_metadata", bundle: bundle, comment: "")) {
                    viewModel.editingBook = entry
                }
                Button(NSLocalizedString("library.export_pdf", bundle: bundle, comment: "")) {
                    viewModel.exportBookAsPDF(entry)
                }
                .disabled(entry.book.format != .epub)
                Divider()
                Button(NSLocalizedString("library.delete", bundle: bundle, comment: ""), role: .destructive) {
                    viewModel.deleteBook(entry)
                }
            }
        } primaryAction: { ids in
            if let id = ids.first, let entry = viewModel.books.first(where: { $0.id == id }) {
                viewModel.openBook(entry)
            }
        }
    }
}
