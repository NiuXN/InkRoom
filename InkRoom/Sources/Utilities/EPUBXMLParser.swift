import Foundation

enum EPUBXMLParser {
    struct OPFResult {
        var title: String?
        var author: String?
        var manifest: [String: ManifestItem] = [:]
        var spineItemRefs: [String] = []
        var coverItemId: String?
    }

    struct ManifestItem {
        var href: String
        var mediaType: String
        var id: String
        var properties: String?
    }

    static func containerRootPath(from data: Data) -> String? {
        let delegate = ContainerDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return delegate.rootPath
    }

    static func parseOPF(from data: Data) -> OPFResult? {
        let delegate = OPFDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return delegate.result
    }

    // MARK: - Container

    private final class ContainerDelegate: NSObject, XMLParserDelegate {
        var rootPath: String?

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let name = localName(from: elementName, qualified: qName)
            guard name == "rootfile" else { return }
            rootPath = attributeDict["full-path"]
                ?? attributeDict["fullPath"]
                ?? attributeDict["Full-Path"]
        }
    }

    // MARK: - OPF

    private final class OPFDelegate: NSObject, XMLParserDelegate {
        var result = OPFResult()
        private var currentElement = ""
        private var textBuffer = ""

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            textBuffer = ""
            let name = localName(from: elementName, qualified: qName)
            currentElement = name

            if name == "item" {
                guard let id = attributeDict["id"], let href = attributeDict["href"] else { return }
                let mediaType = attributeDict["media-type"]
                    ?? attributeDict["mediaType"]
                    ?? "application/xhtml+xml"
                result.manifest[id] = ManifestItem(
                    href: href,
                    mediaType: mediaType,
                    id: id,
                    properties: attributeDict["properties"]
                )
                if attributeDict["properties"]?.contains("cover-image") == true {
                    result.coverItemId = id
                }
            } else if name == "itemref" {
                if let idref = attributeDict["idref"] {
                    result.spineItemRefs.append(idref)
                }
            } else if name == "meta" {
                if attributeDict["name"] == "cover", let content = attributeDict["content"] {
                    result.coverItemId = content
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            textBuffer += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let name = localName(from: elementName, qualified: qName)
            let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            switch name {
            case "title":
                if result.title == nil { result.title = text }
            case "creator":
                if result.author == nil { result.author = text }
            default:
                break
            }
            textBuffer = ""
        }
    }

    private static func localName(from elementName: String, qualified qName: String?) -> String {
        if let qName, let colon = qName.lastIndex(of: ":") {
            return String(qName[qName.index(after: colon)...])
        }
        return elementName
    }
}
