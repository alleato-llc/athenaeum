import SwiftUI
import Ligature

private let bundle = Bundle.module

public struct ReaderView: View {
    let book: EPUBBook
    @StateObject private var viewModel: ReaderViewModel
    @State private var showSidebar: Bool = true
    @State private var showTopBar: Bool = false
    @State private var showBottomBar: Bool = false
    @State private var showHighlightPopover: Bool = false
    @State private var showBookmarkPopover: Bool = false
    @State private var showNotePopover: Bool = false
    @State private var showChapterNotes: Bool = false
    @State private var eventMonitor: Any?

    public init(book: EPUBBook, libraryBookId: String? = nil,
                lastChapterIndex: Int? = nil, lastScrollPosition: Double? = nil,
                fontFamily: String = "Georgia", fontPairingId: String? = nil,
                themeMode: ThemeMode = .system, lightThemeId: String = "classic",
                darkThemeId: String = "charcoal",
                highlights: [Int: [Highlight]] = [:],
                bookmarks: [Bookmark] = [],
                chapterNotes: [Int: String] = [:],
                inlineNotes: [Int: [InlineNote]] = [:]) {
        self.book = book
        _viewModel = StateObject(wrappedValue: ReaderViewModel(
            book: book, libraryBookId: libraryBookId,
            lastChapterIndex: lastChapterIndex, lastScrollPosition: lastScrollPosition,
            fontFamily: fontFamily, fontPairingId: fontPairingId,
            themeMode: themeMode, lightThemeId: lightThemeId, darkThemeId: darkThemeId,
            highlights: highlights, bookmarks: bookmarks,
            chapterNotes: chapterNotes, inlineNotes: inlineNotes))
    }

    private var percentComplete: Int {
        guard viewModel.totalPages > 0 else { return 0 }
        return Int((Double(viewModel.currentPage) / Double(viewModel.totalPages)) * 100)
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * viewModel.readingProgress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.readingProgress)
            }
            .frame(height: 3)

            HSplitView {
                if showSidebar {
                    TOCSidebarView(
                        entries: book.tableOfContents,
                        onSelect: { href in viewModel.navigateTo(href: href) }
                    )
                    .frame(minWidth: 200, maxWidth: 300)
                }

                ZStack(alignment: .center) {
                    EPUBWebView(viewModel: viewModel)
                        .opacity(viewModel.isLoading ? 0 : 1)
                        .animation(.easeIn(duration: 0.2), value: viewModel.isLoading)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        if showTopBar || showHighlightPopover || showBookmarkPopover || showNotePopover || showChapterNotes {
                            ReaderToolbarView(viewModel: viewModel, showSidebar: $showSidebar,
                                              showHighlightPopover: $showHighlightPopover,
                                              showBookmarkPopover: $showBookmarkPopover,
                                              showNotePopover: $showNotePopover,
                                              showChapterNotes: $showChapterNotes)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Color.white.opacity(0.001)
                            .frame(height: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTopBar = hovering
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Color.white.opacity(0.001)
                            .frame(height: 20)
                        if showBottomBar {
                            ReaderNavigationBar(viewModel: viewModel)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBottomBar = hovering
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle(String(format: NSLocalizedString("title.progress", bundle: bundle, comment: "Window title with progress"), percentComplete))
        .onAppear { setupKeyboardHandling() }
        .onDisappear {
            viewModel.saveProgressToLibrary()
            removeKeyboardHandling()
        }
        .sheet(isPresented: $viewModel.showingNoteEditor) {
            NoteEditorSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingInlineNote) { _ in
            NoteDetailSheet(viewModel: viewModel)
        }
    }

    private func setupKeyboardHandling() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 24: // Cmd+=
                    viewModel.zoomIn()
                    return nil
                case 27: // Cmd+-
                    viewModel.zoomOut()
                    return nil
                case 4: // Cmd+H
                    if event.modifierFlags.contains(.shift) && viewModel.libraryBookId != nil {
                        viewModel.toggleHighlightMode()
                        return nil
                    }
                case 11: // Cmd+B
                    if viewModel.libraryBookId != nil {
                        viewModel.addBookmark()
                        return nil
                    }
                case 45: // Cmd+N
                    if event.modifierFlags.contains(.shift) && viewModel.libraryBookId != nil {
                        viewModel.toggleNoteMode()
                        return nil
                    }
                case 6: // Cmd+Z
                    if event.modifierFlags.contains(.shift) {
                        if viewModel.undoManager.canRedo {
                            viewModel.undoManager.redo()
                            return nil
                        }
                    } else {
                        if viewModel.undoManager.canUndo {
                            viewModel.undoManager.undo()
                            return nil
                        }
                    }
                default:
                    break
                }
            }
            switch event.keyCode {
            case 123:
                viewModel.navigateBackward()
                return nil
            case 124:
                viewModel.navigateForward()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyboardHandling() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct TOCSidebarView: View {
    let entries: [EPUBBook.TOCEntry]
    let onSelect: (String) -> Void

    var body: some View {
        List {
            ForEach(entries.indices, id: \.self) { index in
                TOCEntryRow(entry: entries[index], onSelect: onSelect)
            }
        }
        .listStyle(.sidebar)
    }
}

struct TOCEntryRow: View {
    let entry: EPUBBook.TOCEntry
    let onSelect: (String) -> Void

    var body: some View {
        if entry.children.isEmpty {
            Button(action: { onSelect(entry.href) }) {
                Text(entry.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            DisclosureGroup {
                ForEach(entry.children.indices, id: \.self) { index in
                    TOCEntryRow(entry: entry.children[index], onSelect: onSelect)
                }
            } label: {
                Text(entry.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(entry.href) }
            }
        }
    }
}

struct ReaderToolbarView: View {
    @ObservedObject var viewModel: ReaderViewModel

    @Binding var showSidebar: Bool
    @Binding var showHighlightPopover: Bool
    @Binding var showBookmarkPopover: Bool
    @Binding var showNotePopover: Bool
    @Binding var showChapterNotes: Bool

    private var themeModeIcon: String {
        switch viewModel.themeManager.themeMode {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }

    private func applyFonts() {
        guard let webView = viewModel.webView else { return }
        let bodyFont: String? = viewModel.fontPairingId != nil ? viewModel.bodyFontResolved : nil
        viewModel.themeManager.applyStyles(to: webView, fontFamily: viewModel.headerFont,
                                            bodyFont: bodyFont)
    }

    var body: some View {
        HStack {
            Button(action: { withAnimation { showSidebar.toggle() } }) {
                Image(systemName: "sidebar.left")
            }
            .help(NSLocalizedString("Toggle sidebar", bundle: bundle, comment: ""))

            Text(viewModel.book.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Menu {
                // Single font picker (used when no pairing)
                Menu(NSLocalizedString("Font", bundle: bundle, comment: "")) {
                    ForEach(ReadingTheme.availableFonts, id: \.self) { font in
                        Button {
                            viewModel.fontFamily = font
                            viewModel.fontPairingId = nil
                            applyFonts()
                        } label: {
                            HStack {
                                Text(font)
                                if viewModel.fontPairingId == nil && viewModel.fontFamily == font {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                // Font pairings
                Menu(NSLocalizedString("font.pairing", bundle: bundle, comment: "")) {
                    ForEach(FontPairing.pairings) { pairing in
                        Button {
                            viewModel.fontPairingId = pairing.id
                            applyFonts()
                        } label: {
                            HStack {
                                Text(NSLocalizedString(pairing.name, bundle: bundle, comment: ""))
                                if viewModel.fontPairingId == pairing.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Label(NSLocalizedString("Font", bundle: bundle, comment: ""), systemImage: "textformat")
            }

            Button(action: { viewModel.zoomOut() }) {
                Image(systemName: "minus.magnifyingglass")
            }

            Text("\(Int(viewModel.zoom * 100))%")
                .frame(width: 45)
                .monospacedDigit()

            Button(action: { viewModel.zoomIn() }) {
                Image(systemName: "plus.magnifyingglass")
            }

            if viewModel.libraryBookId != nil {
                Button(action: { showHighlightPopover.toggle() }) {
                    Image(systemName: viewModel.isHighlightModeActive ? "highlighter" : "highlighter")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(viewModel.isHighlightModeActive ? Color.accentColor : .primary)
                }
                .help(NSLocalizedString("highlight.toggle", bundle: bundle, comment: ""))
                .popover(isPresented: $showHighlightPopover) {
                    HighlightPopoverView(viewModel: viewModel)
                }

                Button(action: { showBookmarkPopover.toggle() }) {
                    Image(systemName: "bookmark")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(viewModel.bookmarks.isEmpty ? .primary : Color.accentColor)
                }
                .help(NSLocalizedString("bookmark.toggle", bundle: bundle, comment: ""))
                .popover(isPresented: $showBookmarkPopover) {
                    BookmarkPopoverView(viewModel: viewModel)
                }

                Button(action: { showNotePopover.toggle() }) {
                    Image(systemName: "note.text")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(viewModel.isNoteModeActive ? Color.accentColor : .primary)
                }
                .help(NSLocalizedString("notes.toggle", bundle: bundle, comment: ""))
                .popover(isPresented: $showNotePopover) {
                    NoteToolbarPopover(viewModel: viewModel)
                }

                Button(action: { showChapterNotes.toggle() }) {
                    Image(systemName: "doc.text")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(!viewModel.chapterNotes.isEmpty ? Color.accentColor : .primary)
                }
                .help(NSLocalizedString("notes.chapter.toggle", bundle: bundle, comment: ""))
                .popover(isPresented: $showChapterNotes) {
                    ChapterNotesView(viewModel: viewModel)
                }
            }

            Divider().frame(height: 20)

            Button(action: { viewModel.themeManager.cycleThemeMode() }) {
                Image(systemName: themeModeIcon)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct ReaderNavigationBar: View {
    @ObservedObject var viewModel: ReaderViewModel

    private var isAtStart: Bool {
        if viewModel.navigationMode == .chapter {
            return viewModel.currentChapterIndex <= 0
        } else {
            return viewModel.currentChapterIndex <= 0 && viewModel.currentPage <= 1
        }
    }

    private var isAtEnd: Bool {
        if viewModel.navigationMode == .chapter {
            return viewModel.currentChapterIndex >= viewModel.book.spine.count - 1
        } else {
            return viewModel.currentChapterIndex >= viewModel.book.spine.count - 1
                && viewModel.currentPage >= viewModel.totalPages
        }
    }

    var body: some View {
        HStack {
            Button(action: { viewModel.navigateBackward() }) {
                Image(systemName: "chevron.left")
                Text(NSLocalizedString("Previous", bundle: bundle, comment: ""))
            }
            .disabled(isAtStart)

            Spacer()

            HStack(spacing: 4) {
                Text(viewModel.navigationMode == .page
                     ? NSLocalizedString("Page", bundle: bundle, comment: "")
                     : NSLocalizedString("Chapter", bundle: bundle, comment: ""))
                    .onTapGesture(count: 2) {
                        viewModel.toggleNavigationMode()
                    }
                    .help(NSLocalizedString("nav.mode.hint", bundle: bundle, comment: ""))

                if viewModel.navigationMode == .chapter {
                    TextField("", value: $viewModel.goToChapter, format: .number)
                        .frame(width: 40)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .onSubmit { viewModel.navigateToChapter() }
                    Text(String(format: NSLocalizedString("of %d", bundle: bundle, comment: ""), viewModel.book.spine.count))
                } else {
                    Text("\(viewModel.currentPage) \(String(format: NSLocalizedString("of %d", bundle: bundle, comment: ""), viewModel.totalPages))")
                        .monospacedDigit()
                }
            }

            Spacer()

            Button(action: { viewModel.navigateForward() }) {
                Text(NSLocalizedString("Next", bundle: bundle, comment: ""))
                Image(systemName: "chevron.right")
            }
            .disabled(isAtEnd)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
