import SwiftUI

struct BookCard: View {
    let book: Book
    let viewMode: LibraryViewModel.ViewMode

    var body: some View {
        if viewMode == .grid {
            gridCard
        } else {
            listCard
        }
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            ZStack(alignment: .bottomTrailing) {
                CoverImageView(coverURL: book.coverImageURL, title: book.title, isGrid: true)
                    .aspectRatio(0.7, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if book.isStarted {
                    VStack {
                        Spacer()
                        ProgressBar(progress: book.readingProgress)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }

                if book.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.inkRoomPrimary)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(6)
                }
            }

            // Title
            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.inkRoomTextPrimary)
                .lineLimit(1)

            // Author
            Text(book.author)
                .font(.system(size: 11))
                .foregroundColor(.inkRoomTextTertiary)
                .lineLimit(1)
        }
    }

    private var listCard: some View {
        HStack(spacing: 12) {
            // Cover
            CoverImageView(coverURL: book.coverImageURL, title: book.title, isGrid: false)
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.inkRoomTextPrimary)
                    .lineLimit(1)

                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundColor(.inkRoomTextTertiary)
                    .lineLimit(1)

                if book.isStarted {
                    HStack(spacing: 8) {
                        ProgressBar(progress: book.readingProgress)
                        Text("\(Int(book.readingProgress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.inkRoomPrimary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.inkRoomTextTertiary)
        }
        .padding(12)
        .background(Color.inkRoomCard)
        .cornerRadius(12)
    }
}

// MARK: - Async Cover Image
struct CoverImageView: View {
    let coverURL: URL?
    let title: String
    let isGrid: Bool

    @State private var imageData: Data?

    var body: some View {
        ZStack {
            Color.inkRoomPrimaryLight

            if let imageData = imageData, let image = PlatformImage(data: imageData) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                if isGrid {
                    VStack {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.inkRoomPrimary.opacity(0.5))

                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.inkRoomTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(8)
                } else {
                    Image(systemName: "book.closed")
                        .foregroundColor(.inkRoomPrimary.opacity(0.5))
                }
            }
        }
        .task(id: coverURL?.path) {
            guard let coverURL else { return }
            let path = coverURL.path
            if let cached = CoverImageCache.shared.data(for: path) {
                imageData = cached
                return
            }
            let data = await Task.detached(priority: .utility) {
                try? Data(contentsOf: URL(fileURLWithPath: path))
            }.value
            if let data {
                CoverImageCache.shared.store(data, for: path)
                imageData = data
            }
        }
    }
}

#Preview {
    let book = Book(
        title: "人间草木",
        author: "汪曾祺",
        totalPages: 256,
        currentPage: 175,
        lastReadDate: Date(),
        isFavorite: true
    )

    return VStack(spacing: 20) {
        BookCard(book: book, viewMode: .grid)
            .frame(width: 100)

        BookCard(book: book, viewMode: .list)
    }
    .padding()
    .background(Color.inkRoomBackground)
}
