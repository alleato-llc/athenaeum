import SwiftUI
import Forma

#if SWIFT_PACKAGE
private let bundle = Bundle.module
#else
private let bundle = Bundle.main
#endif

struct ChapterNotesReviewView: View {
    let entry: NotesWindowStore.Entry
    @State private var selectedChapterIndex: Int?

    private var hasAnyNotes: Bool {
        !entry.chapterNotes.isEmpty || !entry.inlineNotes.isEmpty
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detail
        }
        .navigationTitle(entry.bookTitle)
    }

    @ViewBuilder
    private var sidebar: some View {
        List(entry.chapters, id: \.index, selection: $selectedChapterIndex) { chapter in
            HStack {
                Text(chapter.title)
                    .lineLimit(2)
                Spacer()
                if entry.chapterNotes[chapter.index] != nil || entry.inlineNotes[chapter.index] != nil {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .tag(chapter.index)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if !hasAnyNotes {
            Text(NSLocalizedString("notes.review.empty", bundle: bundle, comment: ""))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let index = selectedChapterIndex {
            chapterDetail(index: index)
        } else {
            Text(NSLocalizedString("notes.review.empty", bundle: bundle, comment: ""))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func chapterDetail(index: Int) -> some View {
        let chapterNote = entry.chapterNotes[index]
        let notes = entry.inlineNotes[index]
        let hasContent = chapterNote != nil || (notes != nil && !notes!.isEmpty)

        if hasContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let chapterNote = chapterNote {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("notes.review.section.chapter", bundle: bundle, comment: ""))
                                .font(.headline)
                            Text(chapterNote)
                                .textSelection(.enabled)
                        }
                    }

                    if let notes = notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("notes.review.section.inline", bundle: bundle, comment: ""))
                                .font(.headline)

                            ForEach(notes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.text)
                                        .italic()
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                    Text(note.note)
                                        .textSelection(.enabled)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.08)))
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(NSLocalizedString("notes.review.chapter_empty", bundle: bundle, comment: ""))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
