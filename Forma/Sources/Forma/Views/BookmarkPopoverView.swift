import SwiftUI
import Ligature

private let bundle = Bundle.module

struct BookmarkPopoverView: View {
    @ObservedObject var viewModel: ReaderViewModel

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { viewModel.addBookmark() }) {
                Label(NSLocalizedString("bookmark.add", bundle: bundle, comment: ""),
                      systemImage: "bookmark.fill")
            }

            if !viewModel.bookmarks.isEmpty {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.bookmarks) { bookmark in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.label)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(dateFormatter.string(from: bookmark.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.navigateToBookmark(bookmark)
                                }

                                Spacer()

                                Button(action: { viewModel.deleteBookmark(bookmark) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .frame(width: 240)
    }
}
