import SwiftUI

private let bundle = Bundle.module

public struct BookEditView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var title: String
    @State private var authorNames: String
    @State private var year: String
    @State private var genre: String
    @State private var pageCount: String
    @State private var isbn: String
    @State private var coverPath: String?
    private let entry: BookEntry

    @Environment(\.dismiss) private var dismiss

    init(viewModel: LibraryViewModel, entry: BookEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _title = State(initialValue: entry.book.title)
        _authorNames = State(initialValue: entry.authorNames)
        _year = State(initialValue: entry.book.year.map(String.init) ?? "")
        _genre = State(initialValue: entry.book.genre ?? "")
        _pageCount = State(initialValue: entry.book.pageCount.map(String.init) ?? "")
        _isbn = State(initialValue: entry.book.identifiers["isbn"]
                      ?? entry.book.identifiers["isbn13"] ?? "")
        _coverPath = State(initialValue: entry.book.coverPath)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("edit.title", bundle: bundle, comment: ""))
                .font(.headline)
                .padding()

            HStack(alignment: .top, spacing: 20) {
                VStack {
                    BookCoverImage(coverPath: coverPath)
                        .frame(width: 120, height: 170)
                        .cornerRadius(4)
                        .shadow(radius: 3)
                        .onTapGesture { pickCoverImage() }
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            handleCoverDrop(providers: providers)
                            return true
                        }

                    Text(NSLocalizedString("edit.cover.hint", bundle: bundle, comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Form {
                    TextField(NSLocalizedString("edit.field.title", bundle: bundle, comment: ""),
                             text: $title)
                    TextField(NSLocalizedString("edit.field.authors", bundle: bundle, comment: ""),
                             text: $authorNames)
                    TextField(NSLocalizedString("edit.field.year", bundle: bundle, comment: ""),
                             text: $year)
                    TextField(NSLocalizedString("edit.field.genre", bundle: bundle, comment: ""),
                             text: $genre)
                    TextField(NSLocalizedString("edit.field.pages", bundle: bundle, comment: ""),
                             text: $pageCount)
                    TextField(NSLocalizedString("edit.field.isbn", bundle: bundle, comment: ""),
                             text: $isbn)
                }
            }
            .padding()

            Divider()

            HStack {
                Button(NSLocalizedString("edit.cancel", bundle: bundle, comment: "")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(NSLocalizedString("edit.save", bundle: bundle, comment: "")) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func save() {
        var updatedBook = entry.book
        updatedBook.title = title
        updatedBook.year = Int(year)
        updatedBook.genre = genre.isEmpty ? nil : genre
        updatedBook.pageCount = Int(pageCount)
        updatedBook.coverPath = coverPath

        var identifiers = updatedBook.identifiers
        if !isbn.isEmpty {
            if isbn.count == 13 {
                identifiers["isbn13"] = isbn
            } else {
                identifiers["isbn"] = isbn
            }
        } else {
            identifiers.removeValue(forKey: "isbn")
            identifiers.removeValue(forKey: "isbn13")
        }
        updatedBook.identifiers = identifiers

        let authorList = authorNames
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { Author(name: $0) }

        let updatedEntry = BookEntry(id: entry.id, book: updatedBook, authors: authorList)
        viewModel.updateBook(updatedEntry)
    }

    private func pickCoverImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.updateCover(bookId: entry.id, from: url)
            coverPath = (viewModel.books.first { $0.id == entry.id })?.book.coverPath
        }
    }

    private func handleCoverDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                viewModel.updateCover(bookId: entry.id, from: url)
                coverPath = (viewModel.books.first { $0.id == entry.id })?.book.coverPath
            }
        }
    }
}
