import Foundation
#if canImport(Swifter)
import Swifter
#endif

@MainActor
final class WiFiTransferService: ObservableObject {
    static let shared = WiFiTransferService()

    #if canImport(Swifter)
    private var server: HttpServer?
    #endif

    @Published var isRunning = false
    @Published var ipAddress: String = ""
    @Published var port: UInt16 = 8080
    @Published var uploadedFiles: [UploadedFile] = []
    @Published var uploadProgress: [String: Double] = [:]

    private let statusLock = NSLock()
    private var cachedUploadCount = 0
    private var cachedStatusPort: UInt16 = 8080

    private init() {}

    struct UploadedFile: Identifiable {
        let id = UUID()
        let fileName: String
        let fileURL: URL
        let size: Int64
        let uploadedAt: Date
    }

    var isWiFiAvailable: Bool {
        !ipAddress.isEmpty
    }

    // MARK: - Server Control
    func startServer() async throws {
        #if canImport(Swifter)
        stopServer()

        let server = HttpServer()

        // Upload page
        server["/"] = { [weak self] request in
            return .ok(.html(self?.uploadPageHTML ?? ""))
        }

        // Upload handler
        server.post["/upload"] = { [weak self] request in
            guard let self = self else { return .badRequest(.text("Server stopped")) }

            // Parse multipart form data
            if let multipart = parseMultipartFormData(request) {
                for (_, part) in multipart {
                    if let filename = part.filename, !filename.isEmpty {
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let booksDirectory = documentsPath.appendingPathComponent("Books", isDirectory: true)

                        do {
                            try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
                            let destinationURL = booksDirectory.appendingPathComponent(filename)

                            // Remove existing file if present
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }

                            // Write file
                            try part.data.write(to: destinationURL)

                            let fileSize = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0

                            let uploadedFile = UploadedFile(
                                fileName: filename,
                                fileURL: destinationURL,
                                size: Int64(fileSize),
                                uploadedAt: Date()
                            )

                            Task { @MainActor in
                                self.uploadedFiles.insert(uploadedFile, at: 0)
                                self.uploadProgress.removeValue(forKey: filename)
                                self.refreshStatusCache()
                            }

                            // Import the book
                            Task {
                                await self.importUploadedBook(url: destinationURL)
                            }

                        } catch {
                            print("File save error: \(error)")
                            return .internalServerError
                        }
                    }
                }

                return .raw(303, "", ["Location": "/"], nil)
            }

            return .badRequest(.text("No file uploaded"))
        }

        // API endpoint for status
        server["/api/status"] = { [weak self] _ in
            guard let self else { return .ok(.text("{}")) }
            self.statusLock.lock()
            let fileCount = self.cachedUploadCount
            let portValue = self.cachedStatusPort
            self.statusLock.unlock()
            let status = """
            {
              "status": "running",
              "files_uploaded": \(fileCount),
              "port": \(portValue)
            }
            """
            return .ok(.text(status))
        }

        try server.start(port)
        self.server = server
        self.isRunning = true
        self.ipAddress = getWiFiAddress() ?? "Wi-Fi 未连接"
        refreshStatusCache()

        #else
        throw NSError(domain: "WiFiTransfer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Swifter framework not available"])
        #endif
    }

    func stopServer() {
        #if canImport(Swifter)
        server?.stop()
        server = nil
        #endif
        isRunning = false
        ipAddress = ""
        refreshStatusCache()
    }

    private func refreshStatusCache() {
        statusLock.lock()
        cachedUploadCount = uploadedFiles.count
        cachedStatusPort = port
        statusLock.unlock()
    }

    // MARK: - File Import
    private func importUploadedBook(url: URL) async {
        do {
            let book = try await BookParserService.shared.importBook(from: url, copyFile: false)
            let chapters = await BookParserService.shared.getChapters(for: book)
            try await MainActor.run {
                try DatabaseService.shared.insertBook(book)
                if !chapters.isEmpty {
                    try DatabaseService.shared.insertChapters(chapters, forBookId: book.id)
                }
                NotificationCenter.default.post(name: .bookImportedNotification, object: nil)
            }
        } catch {
            print("Book import failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Multipart Parser
    #if canImport(Swifter)
    private func parseMultipartFormData(_ request: HttpRequest) -> [(name: String, part: MultipartPart)]? {
        let contentTypeHeader = request.headers["content-type"] ?? request.headers["Content-Type"] ?? ""
        guard contentTypeHeader.contains("multipart/form-data") else {
            return nil
        }

        // Extract boundary
        let boundaryPattern = #"boundary=([^;]+)"#
        guard let regex = try? NSRegularExpression(pattern: boundaryPattern),
              let match = regex.firstMatch(in: contentTypeHeader, range: NSRange(contentTypeHeader.startIndex..., in: contentTypeHeader)),
              let boundaryRange = Range(match.range(at: 1), in: contentTypeHeader) else {
            return nil
        }

        let boundary = String(contentTypeHeader[boundaryRange])
        let bodyData = Data(request.body)

        return parseMultipartData(bodyData, boundary: boundary)
    }
    #endif

    private struct MultipartPart {
        var data: Data
        var filename: String?
        var contentType: String?
    }

    private func parseMultipartData(_ data: Data, boundary: String) -> [(name: String, part: MultipartPart)] {
        var result: [(name: String, part: MultipartPart)] = []

        // Convert to string for more reliable parsing
        // Multipart bodies are typically ASCII-safe
        guard let bodyString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return result
        }

        let boundaryMarker = "--\(boundary)"
        let crlf = "\r\n"

        // Split by boundary
        let parts = bodyString.components(separatedBy: boundaryMarker)

        for part in parts {
            // Skip empty parts and the closing boundary
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "--" {
                continue
            }

            // Each part starts with \r\n after the boundary, then headers, then \r\n\r\n, then body
            // Find the header/body separator (double CRLF)
            let separator = "\r\n\r\n"
            guard let separatorRange = part.range(of: separator) else {
                // Try with just \n\n as fallback
                guard let altRange = part.range(of: "\n\n") else { continue }
                let headerSection = String(part[part.startIndex..<altRange.lowerBound])
                var bodySection = String(part[altRange.upperBound...])
                // Remove trailing \r\n before next boundary
                if bodySection.hasSuffix("\r\n") {
                    bodySection = String(bodySection.dropLast(2))
                } else if bodySection.hasSuffix("\n") {
                    bodySection = String(bodySection.dropLast())
                }
                if let parsed = parsePartHeadersAndBody(headers: headerSection, body: bodySection) {
                    result.append(parsed)
                }
                continue
            }

            let headerSection = String(part[part.startIndex..<separatorRange.lowerBound])
            var bodySection = String(part[separatorRange.upperBound...])
            // Remove trailing \r\n before next boundary
            if bodySection.hasSuffix("\r\n") {
                bodySection = String(bodySection.dropLast(2))
            } else if bodySection.hasSuffix("\n") {
                bodySection = String(bodySection.dropLast())
            }

            if let parsed = parsePartHeadersAndBody(headers: headerSection, body: bodySection) {
                result.append(parsed)
            }
        }

        return result
    }

    /// Parse headers and body of a single multipart part
    private func parsePartHeadersAndBody(headers: String, body: String) -> (name: String, part: MultipartPart)? {
        // Extract name from Content-Disposition
        var partName = ""
        let namePattern = #"name="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: namePattern),
           let match = regex.firstMatch(in: headers, range: NSRange(headers.startIndex..., in: headers)),
           let range = Range(match.range(at: 1), in: headers) {
            partName = String(headers[range])
        }

        // Extract filename from Content-Disposition
        var filename: String?
        let filenamePattern = #"filename="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: filenamePattern),
           let match = regex.firstMatch(in: headers, range: NSRange(headers.startIndex..., in: headers)),
           let range = Range(match.range(at: 1), in: headers) {
            filename = String(headers[range])
        }

        // Extract content type
        var contentType: String?
        let contentTypePattern = #"Content-Type:\s*([^\r\n]+)"#
        if let regex = try? NSRegularExpression(pattern: contentTypePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: headers, range: NSRange(headers.startIndex..., in: headers)),
           let range = Range(match.range(at: 1), in: headers) {
            contentType = String(headers[range]).trimmingCharacters(in: .whitespaces)
        }

        // Only include parts with a filename (file uploads)
        guard let filename = filename, !filename.isEmpty else {
            return nil
        }

        let bodyData = body.data(using: .utf8) ?? Data()
        let part = MultipartPart(data: bodyData, filename: filename, contentType: contentType)
        return (name: partName, part: part)
    }

    // MARK: - WiFi Address
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "awdl0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }

    // MARK: - Upload Page HTML
    private var uploadPageHTML: String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>墨斋 Wi-Fi 传书</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
                    background: #F5F0E8;
                    color: #2C2C2C;
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                .container {
                    background: white;
                    border-radius: 16px;
                    padding: 40px;
                    max-width: 500px;
                    width: 100%;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.06);
                }
                .header {
                    text-align: center;
                    margin-bottom: 32px;
                }
                .logo {
                    width: 64px;
                    height: 64px;
                    background: #C45C4A;
                    border-radius: 16px;
                    margin: 0 auto 16px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 28px;
                }
                h1 {
                    font-size: 22px;
                    font-weight: 600;
                    margin-bottom: 8px;
                    color: #2C2C2C;
                }
                .subtitle {
                    font-size: 14px;
                    color: #6B6B6B;
                }
                .upload-area {
                    border: 2px dashed rgba(44,44,44,0.16);
                    border-radius: 12px;
                    padding: 40px 20px;
                    text-align: center;
                    cursor: pointer;
                    transition: all 0.2s ease;
                    margin-bottom: 24px;
                }
                .upload-area:hover {
                    border-color: #C45C4A;
                    background: rgba(196,92,74,0.04);
                }
                .upload-area.dragover {
                    border-color: #C45C4A;
                    background: rgba(196,92,74,0.08);
                }
                .upload-icon {
                    font-size: 36px;
                    margin-bottom: 12px;
                    opacity: 0.4;
                }
                .upload-text {
                    font-size: 14px;
                    color: #6B6B6B;
                    margin-bottom: 4px;
                }
                .upload-formats {
                    font-size: 12px;
                    color: #9A9A9A;
                }
                .upload-btn {
                    display: block;
                    width: 100%;
                    padding: 14px;
                    background: #C45C4A;
                    color: white;
                    border: none;
                    border-radius: 12px;
                    font-size: 15px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: opacity 0.2s ease;
                }
                .upload-btn:hover { opacity: 0.9; }
                .upload-btn:disabled { opacity: 0.5; cursor: not-allowed; }
                .file-list {
                    margin-top: 24px;
                }
                .file-item {
                    display: flex;
                    align-items: center;
                    padding: 12px;
                    background: #FAF7F2;
                    border-radius: 8px;
                    margin-bottom: 8px;
                    font-size: 13px;
                }
                .file-item .name {
                    flex: 1;
                    color: #2C2C2C;
                }
                .file-item .status {
                    font-size: 12px;
                    color: #4A8C6F;
                }
                .footer {
                    text-align: center;
                    margin-top: 24px;
                    font-size: 12px;
                    color: #9A9A9A;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="logo">📚</div>
                    <h1>墨斋 Wi-Fi 传书</h1>
                    <p class="subtitle">拖拽或选择文件上传到手机</p>
                </div>

                <form id="uploadForm" enctype="multipart/form-data" method="POST" action="/upload">
                    <div class="upload-area" id="dropArea">
                        <div class="upload-icon">📁</div>
                        <div class="upload-text">拖拽文件到此处上传</div>
                        <div class="upload-formats">支持 .epub .txt 格式</div>
                    </div>

                    <input type="file" id="fileInput" name="file" multiple accept=".epub,.txt" style="display:none">
                    <button type="button" class="upload-btn" id="selectBtn">选择文件上传</button>
                </form>

                <div class="file-list" id="fileList"></div>

                <div class="footer">请保持此页面打开，上传完成后请在手机端查看</div>
            </div>

            <script>
                const dropArea = document.getElementById('dropArea');
                const fileInput = document.getElementById('fileInput');
                const selectBtn = document.getElementById('selectBtn');
                const fileList = document.getElementById('fileList');
                const form = document.getElementById('uploadForm');

                dropArea.addEventListener('click', () => fileInput.click());
                selectBtn.addEventListener('click', () => fileInput.click());

                dropArea.addEventListener('dragover', (e) => {
                    e.preventDefault();
                    dropArea.classList.add('dragover');
                });

                dropArea.addEventListener('dragleave', () => {
                    dropArea.classList.remove('dragover');
                });

                dropArea.addEventListener('drop', (e) => {
                    e.preventDefault();
                    dropArea.classList.remove('dragover');
                    uploadFiles(e.dataTransfer.files);
                });

                fileInput.addEventListener('change', (e) => {
                    uploadFiles(e.target.files);
                });

                async function uploadFiles(files) {
                    if (files.length === 0) return;

                    for (const file of files) {
                        const item = document.createElement('div');
                        item.className = 'file-item';
                        item.innerHTML = `
                            <span class="name">${file.name}</span>
                            <span class="status" id="status-${file.name}">上传中...</span>
                        `;
                        fileList.prepend(item);

                        const formData = new FormData();
                        formData.append('file', file);

                        try {
                            const response = await fetch('/upload', {
                                method: 'POST',
                                body: formData
                            });
                            if (response.ok) {
                                document.getElementById(`status-${file.name}`).textContent = '✓ 上传成功';
                                document.getElementById(`status-${file.name}`).style.color = '#4A8C6F';
                            } else {
                                document.getElementById(`status-${file.name}`).textContent = '✗ 上传失败';
                                document.getElementById(`status-${file.name}`).style.color = '#C44A4A';
                            }
                        } catch (error) {
                            document.getElementById(`status-${file.name}`).textContent = '✗ 上传失败';
                            document.getElementById(`status-${file.name}`).style.color = '#C44A4A';
                        }
                    }
                }
            </script>
        </body>
        </html>
        """
    }
}
