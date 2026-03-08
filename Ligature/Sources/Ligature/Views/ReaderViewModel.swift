import Foundation
import Combine
import WebKit

public enum NavigationMode {
    case page
    case chapter
}

public class ReaderViewModel: ObservableObject {
    public let book: EPUBBook
    public let themeManager: ThemeManager

    @Published public var currentChapterIndex: Int = 0
    @Published public var fontFamily: String = "Georgia"
    @Published public var zoom: Double = 1.0
    @Published public var goToChapter: Int = 1
    @Published public var readingProgress: Double = 0
    @Published public var isLoading: Bool = false
    @Published public var navigationMode: NavigationMode = .page
    @Published public var currentPage: Int = 1
    @Published public var totalPages: Int = 1

    public weak var webView: WKWebView?

    private var scrollPositions: [Int: Double] = [:]
    private var scrollToBottomOnLoad: Bool = false
    private var chapterPageCounts: [Int: Int] = [:]
    private var measuringWebView: WKWebView?
    private var measureQueue: [Int] = []
    private var isMeasuring: Bool = false
    private let measureBatchSize = 5
    private let measureDelay: TimeInterval = 0.1

    private let minZoom: Double = 0.5
    private let maxZoom: Double = 3.0
    private let zoomStep: Double = 0.1

    private var measureCount = 0
    private var themeCancellable: AnyCancellable?

    public var libraryBookId: String?
    private var initialChapterIndex: Int?
    private var initialScrollPosition: Double?

    public init(book: EPUBBook, libraryBookId: String? = nil,
                lastChapterIndex: Int? = nil, lastScrollPosition: Double? = nil,
                themeMode: ThemeMode = .system, lightThemeId: String = "classic",
                darkThemeId: String = "charcoal") {
        self.book = book
        self.libraryBookId = libraryBookId
        self.initialChapterIndex = lastChapterIndex
        self.initialScrollPosition = lastScrollPosition
        self.themeManager = ThemeManager(themeMode: themeMode, lightThemeId: lightThemeId,
                                         darkThemeId: darkThemeId)

        if let chapter = lastChapterIndex, chapter < book.spine.count {
            self.currentChapterIndex = chapter
            self.goToChapter = chapter + 1
        }

        themeCancellable = themeManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.applyThemeStyles()
            }
        }
    }

    deinit {
        saveProgressToLibrary()
        cancelMeasurement()
        book.cleanup()
    }

    public func saveProgressToLibrary() {
        guard let bookId = libraryBookId else { return }
        NotificationCenter.default.post(
            name: .saveReadingProgress,
            object: nil,
            userInfo: [
                "bookId": bookId,
                "chapterIndex": currentChapterIndex,
                "scrollPosition": scrollPositions[currentChapterIndex] ?? 0.0
            ]
        )
    }

    public var currentChapterURL: URL? {
        guard currentChapterIndex >= 0, currentChapterIndex < book.spine.count else { return nil }
        let href = book.spine[currentChapterIndex].href
        return book.baseURL.appendingPathComponent(href)
    }

    public func loadCurrentChapter() {
        guard let url = currentChapterURL else { return }
        isLoading = true
        let request = URLRequest(url: url)
        webView?.load(request)
    }

    public func nextChapter() {
        guard currentChapterIndex < book.spine.count - 1 else { return }
        saveScrollPosition()
        currentChapterIndex += 1
        goToChapter = currentChapterIndex + 1
        loadCurrentChapter()
    }

    public func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        saveScrollPosition()
        currentChapterIndex -= 1
        goToChapter = currentChapterIndex + 1
        loadCurrentChapter()
    }

    public func navigateToChapter() {
        let index = goToChapter - 1
        guard index >= 0, index < book.spine.count else {
            goToChapter = currentChapterIndex + 1
            return
        }
        saveScrollPosition()
        currentChapterIndex = index
        loadCurrentChapter()
    }

    public func navigateTo(href: String) {
        let cleanHref = href.components(separatedBy: "#").first ?? href

        if let index = book.spine.firstIndex(where: { $0.href == cleanHref }) {
            saveScrollPosition()
            currentChapterIndex = index
            goToChapter = index + 1

            if href.contains("#") {
                loadCurrentChapter()
                let fragment = href.components(separatedBy: "#").last ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.webView?.evaluateJavaScript(
                        "document.getElementById('\(fragment)')?.scrollIntoView(true);"
                    )
                }
            } else {
                loadCurrentChapter()
            }
        }
    }

    public func navigateForward() {
        if navigationMode == .chapter {
            nextChapter()
        } else {
            nextPage()
        }
    }

    public func navigateBackward() {
        if navigationMode == .chapter {
            previousChapter()
        } else {
            previousPage()
        }
    }

    public func nextPage() {
        let js = """
        (function() {
            var viewportHeight = window.innerHeight;
            var maxScroll = document.documentElement.scrollHeight - viewportHeight;
            var atBottom = (window.scrollY >= maxScroll - 2);
            return JSON.stringify({ atBottom: atBottom });
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let atBottom = info["atBottom"] as? Bool else { return }

            if atBottom {
                self.nextChapter()
            } else {
                self.webView?.evaluateJavaScript("window.scrollBy(0, window.innerHeight - 40);")
                self.updatePageInfo()
            }
        }
    }

    public func previousPage() {
        let js = """
        (function() {
            var atTop = (window.scrollY <= 2);
            return JSON.stringify({ atTop: atTop });
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let atTop = info["atTop"] as? Bool else { return }

            if atTop {
                if self.currentChapterIndex > 0 {
                    self.saveScrollPosition()
                    self.currentChapterIndex -= 1
                    self.goToChapter = self.currentChapterIndex + 1
                    self.loadCurrentChapter()
                    self.scrollToBottomOnLoad = true
                }
            } else {
                self.webView?.evaluateJavaScript("window.scrollBy(0, -(window.innerHeight - 40));")
                self.updatePageInfo()
            }
        }
    }

    public func updatePageInfo() {
        let js = """
        (function() {
            var viewportHeight = window.innerHeight;
            var docHeight = document.documentElement.scrollHeight;
            var chapterPages = Math.max(1, Math.ceil(docHeight / viewportHeight));
            var pageInChapter = Math.min(chapterPages, Math.floor(window.scrollY / viewportHeight) + 1);
            return JSON.stringify({ pageInChapter: pageInChapter, chapterPages: chapterPages, scrollY: window.scrollY });
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pageInChapter = info["pageInChapter"] as? Int,
                  let chapterPages = info["chapterPages"] as? Int else { return }
            DispatchQueue.main.async {
                if let scrollY = info["scrollY"] as? Double {
                    self.scrollPositions[self.currentChapterIndex] = scrollY
                }

                self.chapterPageCounts[self.currentChapterIndex] = chapterPages

                var pagesBeforeCurrent = 0
                for i in 0..<self.currentChapterIndex {
                    pagesBeforeCurrent += self.chapterPageCounts[i] ?? 1
                }

                self.currentPage = pagesBeforeCurrent + pageInChapter

                var total = 0
                for i in 0..<self.book.spine.count {
                    total += self.chapterPageCounts[i] ?? 1
                }
                self.totalPages = total
                self.updateProgress()
            }
        }
    }

    public func toggleNavigationMode() {
        navigationMode = navigationMode == .page ? .chapter : .page
    }

    public func startMeasuringAllChapters() {
        guard !isMeasuring, let mainWebView = webView else { return }

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let hidden = WKWebView(frame: mainWebView.bounds, configuration: config)
        hidden.isHidden = true
        mainWebView.superview?.addSubview(hidden)
        measuringWebView = hidden

        measureQueue = Array(0..<book.spine.count)
        measureCount = 0
        isMeasuring = true
        measureNextChapter()
    }

    private func cancelMeasurement() {
        measureQueue.removeAll()
        measuringWebView?.stopLoading()
        measuringWebView?.removeFromSuperview()
        measuringWebView = nil
        isMeasuring = false
    }

    private func measureNextChapter() {
        guard let hidden = measuringWebView, !measureQueue.isEmpty else {
            measuringWebView?.removeFromSuperview()
            measuringWebView = nil
            isMeasuring = false
            updatePageInfo()
            return
        }

        let index = measureQueue.removeFirst()
        let href = book.spine[index].href
        let url = book.baseURL.appendingPathComponent(href)

        let delegate = MeasureDelegate { [weak self] pageCount in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.chapterPageCounts[index] = pageCount
                self.measureCount += 1

                // Update totals every batch
                if self.measureCount % self.measureBatchSize == 0 || self.measureQueue.isEmpty {
                    self.updatePageInfo()
                }

                // Throttle: delay before next measurement
                DispatchQueue.main.asyncAfter(deadline: .now() + self.measureDelay) { [weak self] in
                    self?.measureNextChapter()
                }
            }
        }
        objc_setAssociatedObject(hidden, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        hidden.navigationDelegate = delegate
        hidden.load(URLRequest(url: url))
    }

    public func zoomIn() {
        zoom = min(zoom + zoomStep, maxZoom)
        webView?.pageZoom = zoom
    }

    public func zoomOut() {
        zoom = max(zoom - zoomStep, minZoom)
        webView?.pageZoom = zoom
    }

    public func onChapterLoaded() {
        isLoading = false
        applyThemeStyles()
        if scrollToBottomOnLoad {
            scrollToBottomOnLoad = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.webView?.evaluateJavaScript("window.scrollTo(0, document.documentElement.scrollHeight);")
                self?.updatePageInfo()
            }
        } else if let initialScroll = initialScrollPosition, initialScroll > 0 {
            initialScrollPosition = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.webView?.evaluateJavaScript("window.scrollTo(0, \(initialScroll));")
                self?.updatePageInfo()
            }
        } else {
            restoreScrollPosition()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.updatePageInfo()
            if self?.chapterPageCounts.isEmpty == true {
                self?.startMeasuringAllChapters()
            }
        }
    }

    private func applyThemeStyles() {
        guard let webView = webView else { return }
        themeManager.applyStyles(to: webView, fontFamily: fontFamily)
    }

    private func updateProgress() {
        guard totalPages > 0 else { return }
        readingProgress = Double(currentPage) / Double(totalPages)
    }

    public func saveScrollPosition() {
        webView?.evaluateJavaScript("window.scrollY") { [weak self] result, _ in
            if let y = result as? Double {
                self?.scrollPositions[self?.currentChapterIndex ?? 0] = y
            }
        }
    }

    private func restoreScrollPosition() {
        if let y = scrollPositions[currentChapterIndex], y > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.webView?.evaluateJavaScript("window.scrollTo(0, \(y));")
            }
        }
    }
}

private class MeasureDelegate: NSObject, WKNavigationDelegate {
    let completion: (Int) -> Void

    init(completion: @escaping (Int) -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js = """
        (function() {
            var viewportHeight = window.innerHeight;
            var docHeight = document.documentElement.scrollHeight;
            return Math.max(1, Math.ceil(docHeight / viewportHeight));
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            let pages = result as? Int ?? 1
            self?.completion(pages)
        }
    }
}
