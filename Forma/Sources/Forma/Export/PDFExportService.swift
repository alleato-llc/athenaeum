import Foundation
import AppKit
import WebKit
import PDFKit
import Ligature

public enum PDFExportError: LocalizedError {
    case renderFailed
    case noChapters
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .renderFailed: return "Failed to render chapter to PDF."
        case .noChapters: return "The book has no chapters to export."
        case .cancelled: return "Export was cancelled."
        }
    }
}

public class PDFExportService {
    private var isCancelled = false
    private var window: NSWindow?
    private var webView: WKWebView?
    private var fontFamily: String = "Georgia"

    public init() {}

    public func exportToPDF(
        book: EPUBBook,
        fontFamily: String = "Georgia",
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<PDFDocument, Error>) -> Void
    ) {
        guard !book.spine.isEmpty else {
            completion(.failure(PDFExportError.noChapters))
            return
        }

        self.fontFamily = fontFamily
        isCancelled = false

        DispatchQueue.main.async { [weak self] in
            self?.setupWebView()
            self?.renderChapters(book: book, chapterIndex: 0,
                                 cumulativeDocument: PDFDocument(),
                                 hrefPageMap: [:],
                                 progress: progress,
                                 completion: completion)
        }
    }

    public func cancel() {
        isCancelled = true
        DispatchQueue.main.async { [weak self] in
            self?.tearDown()
        }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792), configuration: config)
        let win = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 612, height: 792),
                           styleMask: .borderless, backing: .buffered, defer: true)
        win.contentView = wv
        win.orderBack(nil)

        self.window = win
        self.webView = wv
    }

    private func tearDown() {
        if let wv = webView {
            wv.stopLoading()
            wv.navigationDelegate = nil
            objc_setAssociatedObject(wv, "pdfDelegate", nil, .OBJC_ASSOCIATION_RETAIN)
        }
        webView = nil
        window?.orderOut(nil)
        window = nil
    }

    private func renderChapters(
        book: EPUBBook,
        chapterIndex: Int,
        cumulativeDocument: PDFDocument,
        hrefPageMap: [String: Int],
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<PDFDocument, Error>) -> Void
    ) {
        guard !isCancelled else {
            tearDown()
            completion(.failure(PDFExportError.cancelled))
            return
        }

        guard chapterIndex < book.spine.count else {
            // All chapters rendered — build outline and finish
            buildOutline(document: cumulativeDocument, toc: book.tableOfContents, hrefPageMap: hrefPageMap)
            setMetadata(document: cumulativeDocument, book: book)
            tearDown()
            completion(.success(cumulativeDocument))
            return
        }

        guard let webView = self.webView else {
            completion(.failure(PDFExportError.renderFailed))
            return
        }

        let href = book.spine[chapterIndex].href
        let url = book.baseURL.appendingPathComponent(href)

        var updatedMap = hrefPageMap
        updatedMap[href] = cumulativeDocument.pageCount

        let delegate = PDFRenderDelegate { [weak self] in
            guard let self = self, !self.isCancelled else {
                self?.tearDown()
                completion(.failure(PDFExportError.cancelled))
                return
            }

            self.injectPrintCSS(webView: webView, isFirstChapter: chapterIndex == 0) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self, !self.isCancelled else {
                        self?.tearDown()
                        completion(.failure(PDFExportError.cancelled))
                        return
                    }

                    let pdfConfig = WKPDFConfiguration()
                    // Don't set rect — let WebKit capture and paginate all scrollable content

                    webView.createPDF(configuration: pdfConfig) { [weak self] result in
                        guard let self = self else { return }

                        switch result {
                        case .success(let data):
                            if let chapterPDF = PDFDocument(data: data) {
                                for i in 0..<chapterPDF.pageCount {
                                    if let page = chapterPDF.page(at: i) {
                                        cumulativeDocument.insert(page, at: cumulativeDocument.pageCount)
                                    }
                                }
                            }

                            progress(chapterIndex + 1, book.spine.count)

                            self.renderChapters(book: book, chapterIndex: chapterIndex + 1,
                                                cumulativeDocument: cumulativeDocument,
                                                hrefPageMap: updatedMap,
                                                progress: progress, completion: completion)

                        case .failure:
                            // Skip failed chapters rather than aborting entire export
                            progress(chapterIndex + 1, book.spine.count)
                            self.renderChapters(book: book, chapterIndex: chapterIndex + 1,
                                                cumulativeDocument: cumulativeDocument,
                                                hrefPageMap: updatedMap,
                                                progress: progress, completion: completion)
                        }
                    }
                }
            }
        }

        objc_setAssociatedObject(webView, "pdfDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        webView.navigationDelegate = delegate
        webView.loadFileURL(url, allowingReadAccessTo: book.extractedURL)
    }

    private func injectPrintCSS(webView: WKWebView, isFirstChapter: Bool, completion: @escaping () -> Void) {
        let escapedFont = fontFamily.replacingOccurrences(of: "'", with: "\\'")
        let pageBreakCSS = isFirstChapter ? "" : "body { break-before: page !important; }"
        let js = """
        (function() {
            var style = document.createElement('style');
            style.textContent = `
                \(pageBreakCSS)
                body {
                    font-family: '\(escapedFont)', serif !important;
                    background-color: #ffffff !important;
                    color: #000000 !important;
                    line-height: 1.8 !important;
                    max-width: none !important;
                    margin: 0 !important;
                    padding: 40px 60px !important;
                }
                * { font-family: inherit !important; color: inherit !important; background-color: transparent !important; }
                a { color: #000000 !important; text-decoration: underline !important; }
                img { max-width: 100% !important; height: auto !important; page-break-inside: avoid !important; }
                h1, h2, h3, h4, h5, h6 { page-break-after: avoid !important; }
                p { orphans: 3; widows: 3; }
            `;
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(js) { _, _ in
            completion()
        }
    }

    private func buildOutline(document: PDFDocument, toc: [EPUBBook.TOCEntry], hrefPageMap: [String: Int]) {
        guard !toc.isEmpty, document.pageCount > 0 else { return }

        let root = PDFOutline()
        addOutlineChildren(parent: root, entries: toc, document: document, hrefPageMap: hrefPageMap)
        document.outlineRoot = root
    }

    private func addOutlineChildren(parent: PDFOutline, entries: [EPUBBook.TOCEntry],
                                     document: PDFDocument, hrefPageMap: [String: Int]) {
        for entry in entries {
            let child = PDFOutline()
            child.label = entry.title

            let cleanHref = entry.href.components(separatedBy: "#").first ?? entry.href
            if let pageIndex = hrefPageMap[cleanHref], let page = document.page(at: pageIndex) {
                child.destination = PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).height))
            }

            parent.insertChild(child, at: parent.numberOfChildren)

            if !entry.children.isEmpty {
                addOutlineChildren(parent: child, entries: entry.children,
                                    document: document, hrefPageMap: hrefPageMap)
            }
        }
    }

    private func setMetadata(document: PDFDocument, book: EPUBBook) {
        var attrs: [PDFDocumentAttribute: Any] = [:]
        attrs[.titleAttribute] = book.title
        attrs[.authorAttribute] = book.author
        document.documentAttributes = attrs
    }
}

private class PDFRenderDelegate: NSObject, WKNavigationDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFinish()
    }
}
