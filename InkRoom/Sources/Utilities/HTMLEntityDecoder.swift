import Foundation

/// Decodes HTML entities (named, decimal, hex) to their character equivalents.
enum HTMLEntityDecoder {
    static func decode(_ text: String) -> String {
        var result = text

        // Named entities
        let named: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")
        ]
        for (entity, char) in named {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Decimal entities (&#123;)
        if let decimalRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = decimalRegex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let code = Int(result[codeRange]),
                      let scalar = UnicodeScalar(code) else { continue }
                if let fullRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        // Hex entities (&#x1F;)
        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = hexRegex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let code = Int(result[codeRange], radix: 16),
                      let scalar = UnicodeScalar(code) else { continue }
                if let fullRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result
    }
}
