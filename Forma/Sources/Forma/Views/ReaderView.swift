import SwiftUI
import Ligature

private let bundle = Bundle.module

public struct ReaderView: View {
    let book: EPUBBook
    @StateObject private var viewModel: ReaderViewModel
    @State private var showSidebar: Bool = true
    @State private var showTopBar: Bool = false
    @State private var showBottomBar: Bool = false
    @State private var eventMonitor: Any?

    public init(book: EPUBBook, libraryBookId: String? = nil,
                lastChapterIndex: Int? = nil, lastScrollPosition: Double? = nil,
                fontFamily: String = "Georgia", fontPairingId: String? = nil,
                themeMode: ThemeMode = .system, lightThemeId: String = "classic",
                darkThemeId: String = "charcoal") {
        self.book = book
        _viewModel = StateObject(wrappedValue: ReaderViewModel(
            book: book, libraryBookId: libraryBookId,
            lastChapterIndex: lastChapterIndex, lastScrollPosition: lastScrollPosition,
            fontFamily: fontFamily, fontPairingId: fontPairingId,
            themeMode: themeMode, lightThemeId: lightThemeId, darkThemeId: darkThemeId))
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
                        if showTopBar {
                            ReaderToolbarView(viewModel: viewModel, showSidebar: $showSidebar)
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
