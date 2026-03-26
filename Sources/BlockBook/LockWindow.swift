import AppKit

final class LockWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class LockOverlayView: NSView {
    private enum Layout {
        static let cardPreferredWidth: CGFloat = 420
        static let cardMinWidth: CGFloat = 340
        static let imageWidth: CGFloat = 280
        static let imageHeight: CGFloat = 220
    }

    private let dimView = NSView()
    private let cardView = NSView()
    private let imageView = NSImageView()
    private lazy var imageWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: 0)
    private lazy var imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: 0)

    init(frame frameRect: NSRect, configuration: LockConfiguration) {
        super.init(frame: frameRect)
        setupViewHierarchy(configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func mouseMoved(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func rightMouseDragged(with event: NSEvent) {}
    override func otherMouseDragged(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    override func magnify(with event: NSEvent) {}
    override func smartMagnify(with event: NSEvent) {}
    override func rotate(with event: NSEvent) {}
    override func swipe(with event: NSEvent) {}

    func setPreviewImage(_ image: NSImage?) {
        imageView.image = image
        imageView.isHidden = image == nil
        imageWidthConstraint.constant = image == nil ? 0 : Layout.imageWidth
        imageHeightConstraint.constant = image == nil ? 0 : Layout.imageHeight
    }

    func revealPreview() {
        guard cardView.isHidden else { return }

        dimView.animator().alphaValue = 0.26
        cardView.isHidden = false
        cardView.alphaValue = 0
        cardView.animator().alphaValue = 1
    }

    private func setupViewHierarchy(configuration: LockConfiguration) {
        wantsLayer = true

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.26).cgColor
        dimView.alphaValue = 0
        addSubview(dimView)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        cardView.layer?.cornerRadius = 24
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        cardView.isHidden = true
        addSubview(cardView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.symbolConfiguration = .init(pointSize: 44, weight: .regular)
        cardView.addSubview(imageView)

        let preferredCardWidthConstraint = cardView.widthAnchor.constraint(equalToConstant: Layout.cardPreferredWidth)
        preferredCardWidthConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            preferredCardWidthConstraint,
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.cardPreferredWidth),
            cardView.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.cardMinWidth),
            cardView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.78),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),

            imageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            imageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 28),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -28),
            imageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -28),
            imageWidthConstraint,
            imageHeightConstraint
        ])
    }
}
