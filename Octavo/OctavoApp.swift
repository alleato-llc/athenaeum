import SwiftUI
import AppKit
import Ligature

@main
struct OctavoApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            OctavoContentView()
        }
    }
}

struct OctavoContentView: View {
    @State private var book: EPUBBook?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let book = book {
                ReaderView(book: book)
            } else {
                VStack(spacing: 20) {
                    Text(NSLocalizedString("app.name", bundle: .main, comment: ""))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(NSLocalizedString("landing.prompt", bundle: .main, comment: ""))
                        .foregroundColor(.secondary)
                    Button(NSLocalizedString("landing.open", bundle: .main, comment: "")) {
                        openFile()
                    }
                    .buttonStyle(.borderedProminent)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "epub")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadBook(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                loadBook(from: url)
            }
        }
    }

    private func loadBook(from url: URL) {
        do {
            let parser = EPUBParser()
            self.book = try parser.parse(at: url)
            self.errorMessage = nil
        } catch {
            self.errorMessage = String(format: NSLocalizedString("error.open", bundle: .main, comment: ""), error.localizedDescription)
        }
    }
}
