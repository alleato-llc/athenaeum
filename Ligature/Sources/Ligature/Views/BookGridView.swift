import SwiftUI

private let bundle = Bundle.module

public struct BookGridView: View {
    @ObservedObject var viewModel: LibraryViewModel
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)]

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.books) { entry in
                    BookGridItem(entry: entry, isSelected: viewModel.selectedBookId == entry.id)
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
        Divider()
        Button(NSLocalizedString("library.delete", bundle: bundle, comment: ""), role: .destructive) {
            viewModel.deleteBook(entry)
        }
    }
}

struct BookGridItem: View {
    let entry: BookEntry
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            BookCoverImage(coverPath: entry.book.coverPath)
                .frame(width: 120, height: 170)
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
        .frame(width: 150)
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
