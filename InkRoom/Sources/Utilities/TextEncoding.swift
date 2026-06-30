import Foundation

enum TextEncoding {
    static func readString(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if let text = String(data: data, encoding: gb18030), !text.isEmpty {
            return text
        }

        let gb2312 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)
            )
        )
        if let text = String(data: data, encoding: gb2312), !text.isEmpty {
            return text
        }

        if let text = String(data: data, encoding: .isoLatin1), !text.isEmpty {
            return text
        }

        return nil
    }
}
