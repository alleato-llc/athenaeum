import SwiftUI
import WebKit
import Ligature

public struct EPUBWebView: NSViewRepresentable {
    @ObservedObject var viewModel: ReaderViewModel

    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.userContentController.add(context.coordinator, name: "noteHandler")
        config.userContentController.add(context.coordinator, name: "highlightHandler")
        config.userContentController.add(context.coordinator, name: "scrollHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        viewModel.webView = webView
        viewModel.loadCurrentChapter()
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let viewModel: ReaderViewModel

        init(viewModel: ReaderViewModel) {
            self.viewModel = viewModel
        }

        public func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
            if message.name == "noteHandler" {
                viewModel.handleNoteMessage(message.body)
            } else if message.name == "highlightHandler" {
                viewModel.handleHighlightMessage(message.body)
            } else if message.name == "scrollHandler" {
                viewModel.handleScrollBoundary(message.body)
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.onChapterLoaded()
            webView.pageZoom = viewModel.zoom
        }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                let baseDir = viewModel.book.baseURL.path
                if url.path.hasPrefix(baseDir) {
                    let relativePath = String(url.path.dropFirst(baseDir.count + 1))
                    viewModel.navigateTo(href: relativePath)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
