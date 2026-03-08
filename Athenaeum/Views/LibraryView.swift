import SwiftUI
import Forma

#if SWIFT_PACKAGE
private let bundle = Bundle.module
#else
private let bundle = Bundle.main
#endif

public struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showSettings = false
    @State private var showZoomOverlay = false
    @State private var eventMonitor: Any?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            LibraryToolbar(viewModel: viewModel, showSettings: $showSettings)

            if viewModel.books.isEmpty && viewModel.searchQuery.isEmpty {
                LibraryEmptyView()
            } else if viewModel.books.isEmpty {
                Text(NSLocalizedString("library.no_results", bundle: bundle, comment: ""))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewModel.viewMode {
                case .grid:
                    BookGridView(viewModel: viewModel)
                case .table:
                    BookTableView(viewModel: viewModel)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Color.clear
                        .frame(width: 200, height: 20)

                    if showZoomOverlay {
                        HStack(spacing: 8) {
                            Button(action: { adjustCoverScale(-0.1) }) {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.plain)

                            Slider(value: $viewModel.coverScale, in: 0.5...2.0)
                                .frame(width: 120)

                            Button(action: { adjustCoverScale(0.1) }) {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.bar)
                        .cornerRadius(8)
                        .transition(.opacity)
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showZoomOverlay = hovering
                    }
                }

                ExportJobsButton(jobManager: viewModel.exportJobManager)
            }
            .padding(.trailing, 8)
            .padding(.bottom, 4)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingBook) { entry in
            BookEditView(viewModel: viewModel, entry: entry)
        }
        .sheet(item: $viewModel.directoryImportResult) { result in
            DirectoryImportSummaryView(result: result)
        }
        .overlay {
            if viewModel.isImportingDirectory {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        if let progress = viewModel.directoryImportProgress {
                            Text(String(format: NSLocalizedString("import.directory.progress", bundle: bundle, comment: ""),
                                        progress.current, progress.total))
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Text(NSLocalizedString("import.directory.scanning", bundle: bundle, comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addBooks)) { _ in
            openFilePicker()
        }
        .background(WindowAccessor { viewModel.window = $0 })
        .onAppear { setupKeyboardHandling() }
        .onDisappear { removeKeyboardHandling() }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "epub")!
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            viewModel.importBooks(from: panel.urls)
        }
    }

    private func adjustCoverScale(_ delta: Double) {
        viewModel.coverScale = min(2.0, max(0.5, viewModel.coverScale + delta))
    }

    private func setupKeyboardHandling() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === viewModel.window else { return event }
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 24: // Cmd+=
                    adjustCoverScale(0.1)
                    return nil
                case 27: // Cmd+-
                    adjustCoverScale(-0.1)
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    private func removeKeyboardHandling() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                defer { group.leave() }
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                urls.append(url)
            }
        }
        group.notify(queue: .main) {
            viewModel.importBooks(from: urls)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    init(_ onWindow: @escaping (NSWindow?) -> Void) {
        self.onWindow = onWindow
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}

struct LibraryToolbar: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
            }
            .help(NSLocalizedString("library.settings", bundle: bundle, comment: ""))

            Spacer()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("library.search", bundle: bundle, comment: ""),
                         text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
                    .onChange(of: viewModel.searchQuery) { _ in viewModel.performSearch() }
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                        viewModel.performSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))

            Picker("", selection: $viewModel.viewMode) {
                Image(systemName: "square.grid.2x2").tag(LibraryViewMode.grid)
                Image(systemName: "list.bullet").tag(LibraryViewMode.table)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct LibraryEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("library.empty.title", bundle: bundle, comment: ""))
                .font(.title2)
                .fontWeight(.semibold)
            Text(NSLocalizedString("library.empty.subtitle", bundle: bundle, comment: ""))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
