import Foundation

protocol TOCParser {
    func parse(data: Data) throws -> [EPUBBook.TOCEntry]
}

class EPUB2TOCParser: NSObject, XMLParserDelegate, TOCParser {
    private var entries: [EPUBBook.TOCEntry] = []
    private var entryStack: [(title: String, href: String, children: [EPUBBook.TOCEntry])] = []
    private var currentElement = ""
    private var currentText = ""
    private var currentSrc: String?

    func parse(data: Data) throws -> [EPUBBook.TOCEntry] {
        entries = []
        entryStack = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        currentElement = localName

        if localName == "navPoint" {
            entryStack.append((title: "", href: "", children: []))
        } else if localName == "content" {
            currentSrc = attributes["src"]
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "text", !entryStack.isEmpty {
            entryStack[entryStack.count - 1].title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if localName == "content", !entryStack.isEmpty, let src = currentSrc {
            entryStack[entryStack.count - 1].href = src
            currentSrc = nil
        } else if localName == "navPoint", let current = entryStack.popLast() {
            let entry = EPUBBook.TOCEntry(
                title: current.title,
                href: current.href,
                children: current.children
            )
            if entryStack.isEmpty {
                entries.append(entry)
            } else {
                entryStack[entryStack.count - 1].children.append(entry)
            }
        }
    }
}

class EPUB3TOCParser: NSObject, XMLParserDelegate, TOCParser {
    private var entries: [EPUBBook.TOCEntry] = []
    private var inTocNav = false
    private var listDepth = 0
    private var entryStack: [(title: String, href: String, children: [EPUBBook.TOCEntry])] = []
    private var currentText = ""
    private var currentHref: String?
    private var inAnchor = false

    func parse(data: Data) throws -> [EPUBBook.TOCEntry] {
        entries = []
        entryStack = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        let localName = elementName.lowercased()

        if localName == "nav" {
            let epubType = attributes["epub:type"] ?? attributes["type"] ?? ""
            if epubType == "toc" {
                inTocNav = true
            }
        }

        guard inTocNav else { return }

        if localName == "ol" {
            listDepth += 1
        } else if localName == "a" {
            inAnchor = true
            currentHref = attributes["href"]
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inAnchor {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.lowercased()

        guard inTocNav else { return }

        if localName == "a" {
            inAnchor = false
            let title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            let href = currentHref ?? ""
            entryStack.append((title: title, href: href, children: []))
        } else if localName == "ol" {
            listDepth -= 1
            if listDepth > 0 && entryStack.count > 1 {
                var children: [EPUBBook.TOCEntry] = []
                while entryStack.count > 1 {
                    let last = entryStack.removeLast()
                    children.insert(
                        EPUBBook.TOCEntry(title: last.title, href: last.href, children: last.children),
                        at: 0
                    )
                    if !entryStack.isEmpty && entryStack.last!.children.isEmpty {
                        entryStack[entryStack.count - 1].children = children
                        break
                    }
                }
            }
        } else if localName == "nav" {
            inTocNav = false
            entries = entryStack.map {
                EPUBBook.TOCEntry(title: $0.title, href: $0.href, children: $0.children)
            }
            entryStack = []
        }
    }
}
