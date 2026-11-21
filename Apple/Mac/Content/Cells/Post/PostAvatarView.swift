import AppKit
import Hanami

/// A feed's icon, rounded or circular depending on the feed.
final class PostAvatarView: NSImageView {

    private let size: CGFloat
    private let cornerRadius: CGFloat
    private var representedFeed: Feed?
    private var representedAuthor: ContentAuthor?
    private var iconObserver: ChangeObserver?

    init(size: CGFloat, cornerRadius: CGFloat) {
        self.size = size
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        imageScaling = .scaleProportionallyUpOrDown
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ])
        iconObserver = ChangeObserver {
            _ = FeedIconCache.shared.revision
        } onChange: { [weak self] in
            self?.loadIcon()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(feed: Feed?, article: Article) {
        representedFeed = feed
        representedAuthor = feed?.contentAuthor(of: article)
        image = nil
        layer?.cornerRadius = feed?.isCircleIcon == true ? size / 2 : cornerRadius
        loadIcon()
    }

    private func loadIcon() {
        guard let feed = representedFeed else { return }
        let author = representedAuthor
        FeedIconCache.shared.icon(for: feed, author: author) { [weak self] icon in
            guard self?.representedFeed?.id == feed.id, self?.representedAuthor == author else { return }
            self?.image = icon
        }
    }
}
