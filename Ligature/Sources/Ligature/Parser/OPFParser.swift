import Foundation

struct OPFResult {
    let metadata: EPUBMetadata
    let manifest: [String: ManifestItem]
    let spine: [SpineRef]
    let tocHref: String?
    let ncxHref: String?

    struct ManifestItem {
        let id: String
        let href: String
        let mediaType: String
        let properties: String?
    }

    struct SpineRef {
        let idref: String
    }
}

class OPFParser: NSObject, XMLParserDelegate {
    private var metadata = EPUBMetadata()
    private var manifest: [String: OPFResult.ManifestItem] = [:]
    private var spine: [OPFResult.SpineRef] = []
    private var tocId: String?

    private var currentElement = ""
    private var currentText = ""
    private var inMetadata = false

    func parse(data: Data) throws -> OPFResult {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.parse()

        var tocHref: String?
        var ncxHref: String?

        for (_, item) in manifest {
            if let props = item.properties, props.contains("nav") {
                tocHref = item.href
                break
            }
        }

        if let tocId = tocId, let ncxItem = manifest[tocId] {
            ncxHref = ncxItem.href
        }

        if tocHref == nil {
            tocHref = ncxHref
        }

        return OPFResult(
            metadata: metadata,
            manifest: manifest,
            spine: spine,
            tocHref: tocHref,
            ncxHref: ncxHref
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        switch localName {
        case "package":
            let version = attributes["version"] ?? ""
            metadata.version = EPUBMetadata.EPUBVersion(rawValue: version) ?? .unknown
        case "metadata":
            inMetadata = true
        case "item":
            if let id = attributes["id"],
               let href = attributes["href"],
               let mediaType = attributes["media-type"] {
                let item = OPFResult.ManifestItem(
                    id: id,
                    href: href,
                    mediaType: mediaType,
                    properties: attributes["properties"]
                )
                manifest[id] = item
            }
        case "itemref":
            if let idref = attributes["idref"] {
                spine.append(OPFResult.SpineRef(idref: idref))
            }
        case "spine":
            tocId = attributes["toc"]
        default:
            break
        }

        currentElement = localName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inMetadata {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inMetadata && !trimmed.isEmpty {
            switch localName {
            case "title":
                metadata.title = trimmed
            case "creator":
                metadata.author = trimmed
            case "language":
                metadata.language = trimmed
            case "identifier":
                metadata.identifier = trimmed
            case "publisher":
                metadata.publisher = trimmed
            case "description":
                metadata.description = trimmed
            default:
                break
            }
        }

        if localName == "metadata" {
            inMetadata = false
        }
    }
}
