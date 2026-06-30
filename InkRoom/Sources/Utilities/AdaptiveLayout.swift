import SwiftUI
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

enum LayoutSizeClass: String, CaseIterable, Identifiable {
    case compact
    case regular
    case expanded

    var id: String { rawValue }
}

struct LayoutSizeClassKey: EnvironmentKey {
    static let defaultValue: LayoutSizeClass = .compact
}

struct IsLandscapeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var layoutSizeClass: LayoutSizeClass {
        get { self[LayoutSizeClassKey.self] }
        set { self[LayoutSizeClassKey.self] = newValue }
    }

    var isLandscape: Bool {
        get { self[IsLandscapeKey.self] }
        set { self[IsLandscapeKey.self] = newValue }
    }
}

private struct LayoutInfo: Equatable {
    let sizeClass: LayoutSizeClass
    let isLandscape: Bool
}

private struct LayoutInfoKey: PreferenceKey {
    static var defaultValue: LayoutInfo = LayoutInfo(sizeClass: .compact, isLandscape: false)

    static func reduce(value: inout LayoutInfo, nextValue: () -> LayoutInfo) {
        value = nextValue()
    }
}

struct AdaptiveLayoutModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var layoutInfo = LayoutInfo(sizeClass: .compact, isLandscape: false)

    func body(content: Content) -> some View {
        content
            .environment(\.layoutSizeClass, layoutInfo.sizeClass)
            .environment(\.isLandscape, layoutInfo.isLandscape)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: LayoutInfoKey.self,
                            value: LayoutInfo(
                                sizeClass: calculateSizeClass(from: geometry.size),
                                isLandscape: geometry.size.width > geometry.size.height
                            )
                        )
                }
            }
            .onPreferenceChange(LayoutInfoKey.self) { layoutInfo = $0 }
    }

    private func calculateSizeClass(from size: CGSize) -> LayoutSizeClass {
        let width = size.width

        #if os(macOS)
        if width >= 1024 {
            return .expanded
        } else if width >= 600 {
            return .regular
        } else {
            return .compact
        }
        #else
        if horizontalSizeClass == .regular {
            if width >= 1024 {
                return .expanded
            }
            return .regular
        }

        if width >= 720 {
            return .regular
        }

        return .compact
        #endif
    }
}

extension View {
    func adaptiveLayout() -> some View {
        modifier(AdaptiveLayoutModifier())
    }
}
