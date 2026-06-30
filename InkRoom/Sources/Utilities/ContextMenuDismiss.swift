import Foundation

/// 延后执行上下文菜单中的操作，待菜单完成 dismiss 后再改状态，
/// 避免 `UIContextMenuInteraction updateVisibleMenuWithBlock` 时序警告。
enum ContextMenuDismiss {
    private static let delayNanoseconds: UInt64 = 100_000_000

    static func run(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            action()
        }
    }
}
