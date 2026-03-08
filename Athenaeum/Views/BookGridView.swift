import SwiftUI

#if SWIFT_PACKAGE
private let bundle = Bundle.module
#else
private let bundle = Bundle.main
#endif

public struct BookGridView: View {
    @ObservedObject var viewModel: LibraryViewModel

    private var columns: [GridItem] {
        let minWidth = 150 * viewModel.coverScale
        let maxWidth = 200 * viewModel.coverScale
        return [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: 20)]
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.books) { entry in
                    BookGridItem(entry: entry, isSelected: viewModel.selectedBookId == entry.id,
                                 scale: viewModel.coverScale)
                        .onTapGesture(count: 2) {
                            viewModel.openBook(entry)
                        }
                        .onTapGesture(count: 1) {
                            viewModel.selectedBookId = entry.id
                        }
                        .contextMenu {
                            bookContextMenu(entry: entry)
                        }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func bookContextMenu(entry: BookEntry) -> some View {
        Button(NSLocalizedString("library.edit_metadata", bundle: bundle, comment: "")) {
            viewModel.editingBook = entry
        }
        Button(NSLocalizedString("library.export_pdf", bundle: bundle, comment: "")) {
            viewModel.exportBookAsPDF(entry)
        }
        .disabled(entry.book.format != .epub)
        Divider()
        Button(NSLocalizedString("library.copy", bundle: bundle, comment: "")) {
            viewModel.copyBookToClipboard(entry)
        }
        Button(NSLocalizedString("library.show_in_finder", bundle: bundle, comment: "")) {
            viewModel.showInFinder(entry)
        }
        Button(NSLocalizedString("library.review_notes", bundle: bundle, comment: "")) {
            viewModel.reviewNotes(entry)
        }
        .disabled(entry.book.format != .epub)
        Divider()
        Button(NSLocalizedString("library.delete", bundle: bundle, comment: ""), role: .destructive) {
            viewModel.deleteBook(entry)
        }
    }
}

struct BookGridItem: View {
    let entry: BookEntry
    var isSelected: Bool = false
    var scale: Double = 1.0

    var body: some View {
        VStack(spacing: 8) {
            BookCoverImage(coverPath: entry.book.coverPath)
                .frame(width: 120 * scale, height: 170 * scale)
                .cornerRadius(4)
                .shadow(radius: 3)

            Text(entry.book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(entry.authorNames)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150 * scale)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct BookCoverImage: View {
    let coverPath: String?

    var body: some View {
        if let path = coverPath, let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                Image(systemName: "book.closed")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }
        }
    }
}
