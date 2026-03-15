import AppKit

final class IconPickerViewController: NSViewController {
    var onIconSelected: ((WorkspaceIcon) -> Void)?

    private var segmentedControl: NSSegmentedControl!
    private var searchField: NSSearchField!
    private var collectionView: NSCollectionView!
    private var customField: NSTextField!

    private var currentTab = 0 // 0 = Emoji, 1 = Symbols
    private var searchQuery = ""

    private let itemID = NSUserInterfaceItemIdentifier("IconItem")
    private let headerID = NSUserInterfaceItemIdentifier("SectionHeader")

    // MARK: - Data

    private struct IconSection {
        let title: String
        let items: [IconItem]
    }

    fileprivate enum IconItem {
        case emoji(String)
        case sfSymbol(String)

        var searchText: String {
            switch self {
            case .emoji(let e): return e
            case .sfSymbol(let name): return name
            }
        }
    }

    private let emojiSections: [IconSection] = [
        IconSection(title: "Work", items: [
            "💼", "📁", "🏢", "💻", "🖥", "⌨️", "📊", "📈",
            "💰", "🏦", "📋", "🗂", "📎", "✏️", "🖊", "📝",
        ].map { .emoji($0) }),
        IconSection(title: "Tools", items: [
            "🔧", "⚙️", "🛠", "🔨", "🔩", "🔑", "🗝", "🔐",
            "🧰", "⛏", "🪛", "🪚", "🔬", "🧪", "🧲", "💡",
        ].map { .emoji($0) }),
        IconSection(title: "Symbols", items: [
            "⭐", "🔴", "🟢", "🔵", "🟡", "🟣", "⚡", "💎",
            "🏷", "🔖", "📌", "🎯", "🚀", "🎨", "📦", "💾",
        ].map { .emoji($0) }),
        IconSection(title: "Nature", items: [
            "🌐", "🏠", "🌙", "☀️", "🌊", "🔥", "❄️", "🌿",
            "🌸", "🍀", "🌈", "⛅", "🌍", "🏔", "🌋", "🏝",
        ].map { .emoji($0) }),
        IconSection(title: "Objects", items: [
            "📱", "🎧", "🎮", "🎵", "📸", "🎬", "📺", "🔔",
            "💌", "📫", "🗃", "🗄", "📰", "📚", "🎁", "🧩",
        ].map { .emoji($0) }),
    ]

    private let symbolSections: [IconSection] = [
        IconSection(title: "General", items: [
            "star.fill", "heart.fill", "bolt.fill", "flame.fill",
            "leaf.fill", "drop.fill", "moon.fill", "sun.max.fill",
            "cloud.fill", "snowflake", "sparkles", "wand.and.stars",
            "flag.fill", "bell.fill", "tag.fill", "bookmark.fill",
        ].map { .sfSymbol($0) }),
        IconSection(title: "Devices", items: [
            "desktopcomputer", "laptopcomputer", "iphone", "ipad",
            "keyboard", "display", "tv", "headphones",
            "gamecontroller.fill", "printer.fill", "scanner.fill", "externaldrive.fill",
            "cpu.fill", "memorychip.fill", "wifi", "antenna.radiowaves.left.and.right",
        ].map { .sfSymbol($0) }),
        IconSection(title: "Files", items: [
            "doc.fill", "doc.text.fill", "folder.fill", "folder.badge.gear",
            "archivebox.fill", "tray.fill", "tray.2.fill", "externaldrive.fill",
            "internaldrive.fill", "opticaldiscthedrive.fill", "doc.on.doc.fill", "doc.badge.plus",
            "note.text", "list.bullet", "checklist", "tablecells",
        ].map { .sfSymbol($0) }),
        IconSection(title: "People", items: [
            "person.fill", "person.2.fill", "person.3.fill", "person.badge.key",
            "person.crop.circle.fill", "person.badge.plus", "figure.stand", "brain.head.profile",
            "hand.raised.fill", "hand.thumbsup.fill", "eye.fill", "mouth.fill",
            "terminal", "chevron.left.forwardslash.chevron.right", "hammer.fill", "wrench.and.screwdriver.fill",
        ].map { .sfSymbol($0) }),
    ]

    private var filteredSections: [IconSection] = []

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 380))
        setupUI()
        updateFilteredSections()
    }

    private func setupUI() {
        // Tabs
        segmentedControl = NSSegmentedControl(labels: ["Emoji", "Symbols"], trackingMode: .selectOne, target: self, action: #selector(tabChanged))
        segmentedControl.selectedSegment = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        // Search
        searchField = NSSearchField()
        searchField.placeholderString = "Search..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        // Collection View
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 36, height: 36)
        flowLayout.minimumInteritemSpacing = 2
        flowLayout.minimumLineSpacing = 2
        flowLayout.sectionInset = NSEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)
        flowLayout.headerReferenceSize = NSSize(width: 320, height: 22)

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = flowLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.register(IconCell.self, forItemWithIdentifier: itemID)
        collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: headerID
        )

        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Custom input
        let customLabel = NSTextField(labelWithString: "Custom:")
        customLabel.font = .systemFont(ofSize: 11)
        customLabel.textColor = .secondaryLabelColor
        customLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customLabel)

        customField = NSTextField()
        customField.placeholderString = "Emoji or SF Symbol name + Enter"
        customField.font = .systemFont(ofSize: 13)
        customField.target = self
        customField.action = #selector(customInput)
        customField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customField)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            searchField.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            customLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            customLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),

            customField.topAnchor.constraint(equalTo: customLabel.bottomAnchor, constant: 4),
            customField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            customField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            customField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            customField.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    // MARK: - Filtering

    private func updateFilteredSections() {
        let sections = currentTab == 0 ? emojiSections : symbolSections
        if searchQuery.isEmpty {
            filteredSections = sections
        } else {
            let q = searchQuery.lowercased()
            filteredSections = sections.compactMap { section in
                let filtered = section.items.filter { $0.searchText.lowercased().contains(q) }
                return filtered.isEmpty ? nil : IconSection(title: section.title, items: filtered)
            }
        }
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func tabChanged() {
        currentTab = segmentedControl.selectedSegment
        searchQuery = ""
        searchField.stringValue = ""
        updateFilteredSections()
    }

    @objc private func searchChanged() {
        searchQuery = searchField.stringValue
        updateFilteredSections()
    }

    @objc private func customInput() {
        let val = customField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !val.isEmpty else { return }
        let icon = parseIcon(val)
        onIconSelected?(icon)
        closePopover()
    }

    private func parseIcon(_ val: String) -> WorkspaceIcon {
        if val.unicodeScalars.contains(where: { $0.properties.isEmoji && !$0.properties.isASCIIHexDigit }) && !val.contains(".") {
            return .emoji(val)
        }
        return .sfSymbol(val)
    }

    private func selectItem(_ item: IconItem) {
        let icon: WorkspaceIcon
        switch item {
        case .emoji(let e): icon = .emoji(e)
        case .sfSymbol(let name): icon = .sfSymbol(name)
        }
        onIconSelected?(icon)
        closePopover()
    }

    weak var popover: NSPopover?

    private func closePopover() {
        popover?.close()
    }
}

// MARK: - NSCollectionViewDataSource

extension IconPickerViewController: NSCollectionViewDataSource {
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        filteredSections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredSections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: itemID, for: indexPath) as! IconCell
        let item = filteredSections[indexPath.section].items[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let header = collectionView.makeSupplementaryView(ofKind: kind, withIdentifier: headerID, for: indexPath) as! SectionHeaderView
        header.label.stringValue = filteredSections[indexPath.section].title
        return header
    }
}

// MARK: - NSCollectionViewDelegate

extension IconPickerViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let item = filteredSections[indexPath.section].items[indexPath.item]
        selectItem(item)
        collectionView.deselectItems(at: indexPaths)
    }
}

// MARK: - Icon Cell

private final class IconCell: NSCollectionViewItem {
    private let label = NSTextField(labelWithString: "")
    private let symbolView = NSImageView()

    override func loadView() {
        let cellView = IconCellView(frame: NSRect(x: 0, y: 0, width: 36, height: 36))
        cellView.wantsLayer = true
        cellView.layer?.cornerRadius = 6
        view = cellView

        label.alignment = .center
        label.font = .systemFont(ofSize: 20)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.imageAlignment = .alignCenter
        symbolView.contentTintColor = .labelColor
        view.addSubview(symbolView)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            symbolView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 20),
            symbolView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    func configure(with item: IconPickerViewController.IconItem) {
        switch item {
        case .emoji(let e):
            label.stringValue = e
            label.isHidden = false
            symbolView.isHidden = true
        case .sfSymbol(let name):
            label.isHidden = true
            symbolView.isHidden = false
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            symbolView.image = NSImage(systemSymbolName: name, accessibilityDescription: name)?
                .withSymbolConfiguration(config)
        }
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
                : nil
        }
    }
}

private final class IconCellView: NSView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }
}

// MARK: - Section Header

private final class SectionHeaderView: NSView, NSCollectionViewSectionHeaderView {
    let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
