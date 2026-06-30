import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: LibraryViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @State private var showFilePicker = false
    @State private var uploadTasks: [UploadTask] = []
    @State private var showError = false
    @State private var showAirDropHint = false
    @State private var localError: String?
    @ObservedObject private var wifiService = WiFiTransferService.shared

    private static let maxFileSize: Int64 = 100 * 1024 * 1024

    struct UploadTask: Identifiable {
        let id = UUID()
        let fileName: String
        let fileURL: URL?
        var status: Status
        var progress: Double

        enum Status: Equatable {
            case pending
            case uploading
            case success
            case failed(String)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    wifiTransferCard
                    uploadArea

                    if !uploadTasks.isEmpty {
                        uploadTaskList
                    }

                    otherMethodsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, LayoutMetrics.bottomInsetForTabBar)
            }
            .background(Color.inkRoomBackground)
            .navigationTitle("导入书籍")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.epub, .plainText],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .alert("导入失败", isPresented: $showError) {
                Button("确定") {
                    viewModel.errorMessage = nil
                    localError = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? localError ?? "")
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showError = newValue != nil
            }
            .onChange(of: localError) { _, newValue in
                if newValue != nil { showError = true }
            }
            .task {
                await ensureWiFiServerRunning()
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookImportedNotification)) { _ in
                syncWiFiUploadTasks()
            }
        }
    }

    private var wifiTransferCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.inkRoomPrimary)

                Text("Wi-Fi 传书")
                    .font(.inkRoomHeadline)
                    .foregroundStyle(Color.inkRoomTextPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(wifiService.isRunning ? Color.stateSuccess : Color.inkRoomTextTertiary)
                        .frame(width: 8, height: 8)

                    Text(wifiService.isRunning ? "已开启" : "未开启")
                        .font(.inkRoomFootnote)
                        .foregroundStyle(wifiService.isRunning ? .stateSuccess : Color.inkRoomTextTertiary)
                }
            }

            Text(wifiService.isRunning
                 ? "确保手机与电脑在同一 Wi-Fi 网络下"
                 : "请在「我的 → 传书」中开启 Wi-Fi 传书")
                .font(.inkRoomSubheadlineRegular)
                .foregroundStyle(Color.inkRoomTextTertiary)

            if wifiService.isRunning {
                let transferURL = wifiService.ipAddress.isEmpty
                    ? ""
                    : "http://\(wifiService.ipAddress):\(wifiService.port)"

                HStack(spacing: 20) {
                    if !transferURL.isEmpty {
                        VStack(spacing: 8) {
                            QRCodeView(content: transferURL, size: 100)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))

                            Text("扫码传书")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                        }
                    }

                    VStack(spacing: 4) {
                        Text(wifiService.ipAddress.isEmpty ? "正在获取..." : transferURL.replacingOccurrences(of: "http://", with: ""))
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.inkRoomOnPrimary)
                            .multilineTextAlignment(.center)

                        Text("在电脑浏览器中输入此地址")
                            .font(.inkRoomCaption)
                            .foregroundStyle(Color.inkRoomOnPrimary.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.inkRoomPrimary)
                    .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))
                    .shadow(color: Color.inkRoomPrimary.opacity(0.3), radius: 8, y: 2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(LayoutMetrics.cardPadding)
        .background(Color.inkRoomCard)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
    }

    private var uploadArea: some View {
        Button {
            showFilePicker = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.inkRoomTextTertiary)

                Text("选择文件导入")
                    .font(.inkRoomHeadline)
                    .foregroundStyle(Color.inkRoomTextSecondary)

                Text(".epub  .txt")
                    .font(.inkRoomFootnote)
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusCard)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(Color.inkRoomTextTertiary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        Task { @MainActor in
                            await importFile(url: url, taskId: UUID())
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    private var uploadTaskList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("导入任务")
                    .font(.inkRoomSubheadline)
                    .foregroundStyle(Color.inkRoomTextSecondary)

                Spacer()

                if uploadTasks.contains(where: { $0.status == .uploading }) {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            VStack(spacing: 8) {
                ForEach(uploadTasks) { task in
                    uploadTaskRow(task)
                }
            }
        }
    }

    private func uploadTaskRow(_ task: UploadTask) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor(task.status).opacity(0.15))
                    .frame(width: 36, height: 36)

                switch task.status {
                case .pending, .uploading:
                    if task.status == .uploading {
                        ProgressView()
                            .tint(Color.inkRoomPrimary)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.inkRoomTextTertiary)
                    }
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.stateSuccess)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.stateError)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.fileName)
                    .font(.inkRoomBodyEmphasized)
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .lineLimit(1)

                switch task.status {
                case .pending:
                    Text("等待中...")
                        .font(.inkRoomCaption)
                        .foregroundStyle(Color.inkRoomTextTertiary)
                case .uploading:
                    HStack(spacing: 8) {
                        ProgressBar(progress: task.progress)
                        Text("\(Int(task.progress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.inkRoomPrimary)
                    }
                case .success:
                    Text("导入成功")
                        .font(.inkRoomCaption)
                        .foregroundStyle(Color.stateSuccess)
                case .failed(let reason):
                    Text(reason)
                        .font(.inkRoomCaption)
                        .foregroundStyle(Color.stateError)
                }
            }

            Spacer()

            if case .failed = task.status {
                InkRoomChipButton(
                    title: "重试",
                    isSelected: false,
                    accessibilityLabel: "重试导入"
                ) {
                    if let url = task.fileURL {
                        viewModel.errorMessage = nil
                        Task {
                            await importFile(url: url, taskId: task.id)
                        }
                    }
                }
            }
        }
        .padding(LayoutMetrics.cardPaddingCompact)
        .background(Color.inkRoomCard)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
    }

    private func statusColor(_ status: UploadTask.Status) -> Color {
        switch status {
        case .pending, .uploading: return .inkRoomPrimary
        case .success: return .stateSuccess
        case .failed: return .stateError
        }
    }

    private var otherMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("其他导入方式")
                .font(.inkRoomSubheadline)
                .foregroundStyle(Color.inkRoomTextSecondary)

            VStack(spacing: 0) {
                Button {
                    showAirDropHint = true
                } label: {
                    HStack(spacing: 12) {
                        IconBadgeView(icon: "airplayaudio", iconSize: 16, badgeSize: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("隔空投送")
                                .font(.inkRoomHeadline)
                                .foregroundStyle(Color.inkRoomTextPrimary)

                            Text("通过 AirDrop 发送文件到墨斋")
                                .font(.inkRoomFootnote)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.inkRoomBody)
                            .foregroundStyle(Color.inkRoomTextTertiary)
                    }
                    .padding(14)
                }

                Divider()
                    .padding(.leading, 62)

                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 12) {
                        IconBadgeView(icon: "folder", iconSize: 16, badgeSize: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("文件 App")
                                .font(.inkRoomHeadline)
                                .foregroundStyle(Color.inkRoomTextPrimary)

                            Text("在「文件」中选择墨斋打开")
                                .font(.inkRoomFootnote)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.inkRoomBody)
                            .foregroundStyle(Color.inkRoomTextTertiary)
                    }
                    .padding(14)
                }
            }
            .background(Color.inkRoomCard)
            .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))

            Text("支持 epub 和 txt 格式，单文件最大 100MB")
                .font(.inkRoomCaption)
                .foregroundStyle(Color.inkRoomTextTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .alert("隔空投送", isPresented: $showAirDropHint) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请从其他应用使用「分享」按钮，选择「隔空投送」或「墨斋」将文件发送到本应用。")
        }
    }

    private func ensureWiFiServerRunning() async {
        guard settingsViewModel.wifiTransferEnabled, !wifiService.isRunning else { return }
        try? await wifiService.startServer()
    }

    private func syncWiFiUploadTasks() {
        for file in wifiService.uploadedFiles {
            guard !uploadTasks.contains(where: { $0.fileName == file.fileName && $0.status == .success }) else { continue }
            uploadTasks.insert(
                UploadTask(fileName: file.fileName, fileURL: file.fileURL, status: .success, progress: 1.0),
                at: 0
            )
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    if let error = validateFile(at: url) {
                        let task = UploadTask(fileName: url.lastPathComponent, fileURL: url, status: .failed(error), progress: 0)
                        uploadTasks.append(task)
                        continue
                    }

                    let task = UploadTask(fileName: url.lastPathComponent, fileURL: url, status: .uploading, progress: 0)
                    uploadTasks.append(task)
                    await importFile(url: url, taskId: task.id)
                }
            }
        case .failure(let error):
            localError = error.localizedDescription
        }
    }

    private func validateFile(at url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ext == "epub" || ext == "txt" else {
            return "不支持的文件格式"
        }

        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           Int64(size) > Self.maxFileSize {
            return "文件超过 100MB 限制"
        }

        return nil
    }

    private func importFile(url: URL, taskId: UUID) async {
        if let index = uploadTasks.firstIndex(where: { $0.id == taskId }) {
            uploadTasks[index].status = .uploading
            uploadTasks[index].progress = 0.05
        }

        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Stage 1: File access (10%)
        if let index = uploadTasks.firstIndex(where: { $0.id == taskId }) {
            uploadTasks[index].progress = 0.1
        }

        // Stage 2: Copy file (20%)
        if let index = uploadTasks.firstIndex(where: { $0.id == taskId }) {
            uploadTasks[index].progress = 0.2
        }

        // Stage 3: Parse book (30% -> 80%)
        // Simulate progress during parsing since BookParserService doesn't expose progress yet
        let progressTask = Task {
            while !Task.isCancelled {
                if let index = uploadTasks.firstIndex(where: { $0.id == taskId }) {
                    if uploadTasks[index].progress < 0.8 {
                        uploadTasks[index].progress += 0.02
                    }
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        await viewModel.importBook(from: url)

        progressTask.cancel()

        // Stage 4: Save to database (90%)
        if let index = uploadTasks.firstIndex(where: { $0.id == taskId }) {
            uploadTasks[index].progress = 0.9
        }

        // Stage 5: Complete (100%)
        if let index = uploadTasks.firstIndex(where: { $0.id == taskId }) {
            if viewModel.errorMessage == nil {
                uploadTasks[index].status = .success
                uploadTasks[index].progress = 1.0
            } else {
                uploadTasks[index].status = .failed(viewModel.errorMessage ?? "导入失败")
            }
        }
    }
}

#Preview {
    ImportView()
        .environmentObject(LibraryViewModel())
        .environmentObject(SettingsViewModel())
}
