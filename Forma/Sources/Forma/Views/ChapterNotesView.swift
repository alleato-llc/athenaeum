import SwiftUI
import Ligature

private let bundle = Bundle.module

struct ChapterNotesView: View {
    @ObservedObject var viewModel: ReaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("notes.chapter", bundle: bundle, comment: ""))
                .font(.headline)

            Text(viewModel.chapterTitle(for: viewModel.currentChapterIndex))
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $viewModel.chapterNotes)
                .font(.body)
                .frame(minHeight: 120)

            HStack {
                Spacer()
                Button(NSLocalizedString("notes.save", bundle: bundle, comment: "")) {
                    viewModel.saveChapterNotesToLibrary()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .frame(width: 320)
        .frame(minHeight: 200)
    }
}
