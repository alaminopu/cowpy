import Foundation

/// Reads and writes the snippet XML format that Clipy (and ClipMenu before it)
/// uses, so snippets can move between the apps:
///
///     <folders>
///       <folder>
///         <title>Greetings</title>
///         <snippets>
///           <snippet><title>Hi</title><content>Hello there</content></snippet>
///         </snippets>
///       </folder>
///     </folders>
nonisolated enum SnippetArchive {
    struct Folder: Equatable, Sendable {
        var title: String
        var snippets: [Snippet]
    }

    struct Snippet: Equatable, Sendable {
        var title: String
        var content: String
    }

    enum ArchiveError: LocalizedError {
        case notASnippetFile

        var errorDescription: String? {
            "This file does not look like a Cowpy or Clipy snippet export."
        }
    }

    static func xmlData(for folders: [Folder]) -> Data {
        let root = XMLElement(name: "folders")
        for folder in folders {
            let folderElement = XMLElement(name: "folder")
            folderElement.addChild(XMLElement(name: "title", stringValue: folder.title))

            let snippetsElement = XMLElement(name: "snippets")
            for snippet in folder.snippets {
                let snippetElement = XMLElement(name: "snippet")
                snippetElement.addChild(XMLElement(name: "title", stringValue: snippet.title))
                snippetElement.addChild(XMLElement(name: "content", stringValue: snippet.content))
                snippetsElement.addChild(snippetElement)
            }
            folderElement.addChild(snippetsElement)
            root.addChild(folderElement)
        }

        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return document.xmlData(options: [.nodePrettyPrint])
    }

    static func folders(fromXML data: Data) throws -> [Folder] {
        // Whitespace inside <content> is the user's text; keep it exactly.
        let document = try XMLDocument(data: data, options: [.nodePreserveWhitespace])
        guard let root = document.rootElement(), root.name == "folders" else {
            throw ArchiveError.notASnippetFile
        }

        return root.elements(forName: "folder").map { folderElement in
            let snippets = folderElement.elements(forName: "snippets")
                .flatMap { $0.elements(forName: "snippet") }
                .map { snippetElement in
                    Snippet(
                        title: snippetElement.firstValue(of: "title"),
                        content: snippetElement.firstValue(of: "content")
                    )
                }
            return Folder(title: folderElement.firstValue(of: "title"), snippets: snippets)
        }
    }
}

private nonisolated extension XMLElement {
    func firstValue(of name: String) -> String {
        elements(forName: name).first?.stringValue ?? ""
    }
}
