import Foundation

public class ContainerXMLParser: NSObject, XMLParserDelegate {
    private var opfPath: String?

    public override init() { super.init() }

    public func parse(data: Data) throws -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        guard let path = opfPath else {
            throw EPUBError.opfNotFound
        }
        return path
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if elementName == "rootfile" || elementName.hasSuffix(":rootfile") {
            opfPath = attributes["full-path"]
        }
    }
}
