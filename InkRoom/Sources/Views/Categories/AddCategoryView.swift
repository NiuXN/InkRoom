import SwiftUI

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "book.fill"
    @State private var selectedColorHex: String = "#C45C4A"

    var onSave: (Category) -> Void

    private let icons = [
        "book.fill", "books.vertical.fill", "pencil", "globe",
        "music.note", "film", "cup.and.saucer", "leaf",
        "heart.fill", "star.fill", "flag.fill", "folder.fill"
    ]

    private let colors = [
        "#C45C4A", "#4A7BC4", "#4A8C6F", "#C49A4A",
        "#8C5AC4", "#C45A8C", "#5AC4C4", "#7C8C9A"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("分类名称", text: $name)
                } header: {
                    Text("名称")
                        .textCase(nil)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: selectedColorHex) ?? Color.inkRoomPrimary : Color.inkRoomBackgroundElevated)
                                        .frame(width: 44, height: 44)

                                    Image(safeSystemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(selectedIcon == icon ? Color.inkRoomOnPrimary : Color.inkRoomTextSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("图标")
                        .textCase(nil)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { colorHex in
                            Button {
                                selectedColorHex = colorHex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: colorHex) ?? Color.inkRoomTextTertiary)
                                        .frame(width: 32, height: 32)

                                    if selectedColorHex == colorHex {
                                        Circle()
                                            .stroke(Color.inkRoomOnPrimary, lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("颜色")
                        .textCase(nil)
                }

                Section {
                    HStack {
                        Spacer()
                        CategoryPreviewCard(name: name.isEmpty ? "分类名称" : name, icon: selectedIcon, colorHex: selectedColorHex)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
            .background(Color.inkRoomBackground)
            .navigationTitle("新建分类")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let category = Category(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            iconName: selectedIcon,
                            colorHex: selectedColorHex
                        )
                        onSave(category)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 520)
        #endif
    }
}

struct CategoryPreviewCard: View {
    let name: String
    let icon: String
    let colorHex: String

    var body: some View {
        HStack(spacing: 12) {
            IconBadgeView(
                icon: icon,
                iconSize: 18,
                badgeSize: 40,
                color: Color(hex: colorHex) ?? Color.inkRoomTextTertiary,
                background: Color(hex: colorHex)?.opacity(0.15) ?? Color.inkRoomTextTertiary.opacity(0.15)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.inkRoomBodyEmphasized)
                    .foregroundStyle(Color.inkRoomTextPrimary)

                Text("0 本")
                    .font(.inkRoomCaption)
                    .foregroundStyle(Color(hex: colorHex) ?? Color.inkRoomTextTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: colorHex)?.opacity(0.1) ?? Color.inkRoomTextTertiary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 4))
            }

            Spacer()
        }
        .padding(LayoutMetrics.cardPadding)
        .frame(width: 240)
        .background(Color.inkRoomCard)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
    }
}

#Preview {
    AddCategoryView { _ in }
}
