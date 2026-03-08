import SwiftUI

private let bundle = Bundle.module

public struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showSettings = false

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
        .onReceive(NotificationCenter.default.publisher(for: .addBooks)) { _ in
            openFilePicker()
        }
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
