import SwiftUI
import Ligature

private let bundle = Bundle.module

struct NoteEditorSheet: View {
    @ObservedObject var viewModel: ReaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("notes.addInline", bundle: bundle, comment: ""))
                .font(.headline)

            TextEditor(text: $viewModel.pendingNoteText)
                .font(.body)
                .frame(minHeight: 80)

            HStack {
                Button(NSLocalizedString("Cancel", bundle: bundle, comment: "")) {
                    viewModel.cancelPendingNote()
                }
                .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(NSLocalizedString("notes.save", bundle: bundle, comment: "")) {
                    viewModel.confirmPendingNote()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.pendingNoteText.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .frame(minHeight: 150)
    }
}

struct NoteDetailSheet: View {
    @ObservedObject var viewModel: ReaderViewModel
    @State private var editedText: String = ""
    @State private var isEditing: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        if let note = viewModel.editingInlineNote {
            VStack(alignment: .leading, spacing: 12) {
                Text(note.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Divider()

                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.body)
                        .frame(minHeight: 80)
                } else {
                    Text(note.note)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .alert(NSLocalizedString("notes.delete.confirm", bundle: bundle, comment: ""),
                           isPresented: $showDeleteConfirmation) {
                        Button(NSLocalizedString("notes.delete", bundle: bundle, comment: ""),
                               role: .destructive) {
                            viewModel.deleteInlineNote(note)
                        }
                        Button(NSLocalizedString("Cancel", bundle: bundle, comment: ""), role: .cancel) {}
                    }

                    Spacer()

                    if isEditing {
                        Button(NSLocalizedString("Cancel", bundle: bundle, comment: "")) {
                            isEditing = false
                        }
                        Button(NSLocalizedString("notes.save", bundle: bundle, comment: "")) {
                            viewModel.updateInlineNote(note, newText: editedText)
                            isEditing = false
                        }
                        .disabled(editedText.isEmpty)
                    } else {
                        Button(NSLocalizedString("notes.edit", bundle: bundle, comment: "")) {
                            editedText = note.note
                            isEditing = true
                        }
                        Button(NSLocalizedString("notes.dismiss", bundle: bundle, comment: "")) {
                            viewModel.editingInlineNote = nil
                        }
                    }
                }
            }
            .padding()
            .frame(width: 300)
        .frame(minHeight: 150)
        }
    }
}

struct NoteToolbarPopover: View {
    @ObservedObject var viewModel: ReaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { viewModel.isNoteModeActive },
                set: { _ in viewModel.toggleNoteMode() }
            )) {
                Label(NSLocalizedString("notes.inlineMode", bundle: bundle, comment: ""),
                      systemImage: "note.text")
            }

            let c = HighlightColor.noteSwiftUIColor
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: c.red, green: c.green, blue: c.blue, opacity: c.opacity))
                    .frame(width: 16, height: 16)
                Text(NSLocalizedString("notes.noteColor", bundle: bundle, comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 220)
    }
}
