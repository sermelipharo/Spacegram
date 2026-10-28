import Foundation
import TGUIKit
import Cocoa
import TelegramCore
import Postbox
import Localization
import TelegramContext
import TelegramTheme
import TelegramUtils
import LocalAnimations
import GeneralRows

public final class ChatListFolderColumnItem : GeneralRowItem {
    fileprivate let folder: ChatListFilter
    fileprivate let isCurrentFolder: Bool
    fileprivate let unreadCount: Int
    fileprivate let hasUnmutedUnread: Bool
    fileprivate let invoke: ()->Void
    fileprivate let icon: CGImage
    fileprivate let titleLayout: TextViewLayout
    fileprivate let countLayout: TextViewLayout?

    public init(_ initialSize: NSSize, stableId: AnyHashable, folder: ChatListFilter, selected: Bool, unreadCount: Int, hasUnmutedUnread: Bool, invoke: @escaping()->Void) {
        self.folder = folder
        self.isCurrentFolder = selected
        self.unreadCount = unreadCount
        self.hasUnmutedUnread = hasUnmutedUnread
        self.invoke = invoke
        self.icon = FolderIcon(folder).icon(for: selected ? .sidebarActive : .sidebar, image: { name in
            return NSImage(named: name) ?? NSImage()
        })
        self.titleLayout = TextViewLayout(.initialize(string: folder.title, color: selected ? theme.colors.accent : theme.colors.text, font: .medium(10)), maximumNumberOfLines: 1, truncationType: .end)
        if unreadCount > 0 {
            self.countLayout = TextViewLayout(.initialize(string: unreadCount.prettyNumber, color: .white, font: .medium(8)), maximumNumberOfLines: 1)
        } else {
            self.countLayout = nil
        }
        super.init(initialSize, stableId: stableId)
    }

    public override var height: CGFloat {
        return 32
    }

    public override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        countLayout?.measure(width: 24)
        titleLayout.measure(width: width - 8 - 8 - 6 - 18 - 4 - 4)
        return true
    }

    public override func viewClass() -> AnyClass {
        return ChatListFolderColumnView.self
    }

    public override var accessibilityLabel: String? {
        return folder.title
    }

    public override var accessibilityRole: NSAccessibility.Role? {
        return .button
    }

    public override func accessibilityPerformPress() -> Bool {
        invoke()
        return true
    }
}

private final class ChatListFolderColumnView: TableRowView {
    private let plate = View()
    private let iconView = ImageView()
    private let titleView = TextView()
    private let countView = TextView()
    private let countBadge = View()
    private let overlay = Control()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        plate.layer?.cornerRadius = 10
        if #available(macOS 10.15, *) {
            plate.layer?.cornerCurve = .continuous
        }
        addSubview(plate)
        plate.addSubview(iconView)
        plate.addSubview(titleView)
        plate.addSubview(countBadge)
        plate.addSubview(countView)
        plate.addSubview(overlay)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        countView.userInteractionEnabled = false
        countView.isSelectable = false
        iconView.layer?.contentsGravity = .resizeAspect

        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? ChatListFolderColumnItem {
                item.invoke()
            }
        }, for: .Click)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var backdorColor: NSColor {
        return .clear
    }

    override func layout() {
        super.layout()
        plate.frame = NSMakeRect(8, 2, frame.width - 16, frame.height - 4)
        overlay.frame = plate.bounds
        iconView.frame = NSMakeRect(6, (plate.frame.height - 18) / 2, 18, 18)
        if !countView.isHidden {
            countBadge.frame = NSMakeRect(max(0, iconView.frame.minX - 5), iconView.frame.minY - 3, countView.frame.width + 8, 12)
            countBadge.layer?.cornerRadius = 6
            countView.setFrameOrigin(NSMakePoint(countBadge.frame.minX + 4, countBadge.frame.minY + floorToScreenPixels((12 - countView.frame.height) / 2)))
        }
        titleView.setFrameOrigin(NSMakePoint(iconView.frame.maxX + 4, floorToScreenPixels((plate.frame.height - titleView.frame.height) / 2)))
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ChatListFolderColumnItem else {
            return
        }
        plate.backgroundColor = item.isCurrentFolder ? theme.colors.accent.withAlphaComponent(0.14) : .clear
        iconView.image = item.icon
        titleView.update(item.titleLayout)
        if let count = item.countLayout {
            countView.isHidden = false
            countBadge.isHidden = false
            countBadge.backgroundColor = item.isCurrentFolder || item.hasUnmutedUnread ? theme.colors.accent : theme.colors.grayIcon
            countView.update(count)
        } else {
            countView.isHidden = true
            countBadge.isHidden = true
        }
        overlay.setAccessibilityLabel(item.folder.title)
        needsLayout = true
    }
}

final class ChatListFolderDock: NSVisualEffectView {
    private let table = TableView(frame: .zero)
    private(set) var rowCount: Int = 0

    static let rowHeight: CGFloat = 32
    static let padding: CGFloat = 6

    var contentHeight: CGFloat {
        return rowCount > 0 ? CGFloat(rowCount) * ChatListFolderDock.rowHeight + ChatListFolderDock.padding * 2 : 0
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .sidebar
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        addSubview(table)
        table.backgroundColor = .clear
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        table.frame = NSMakeRect(0, ChatListFolderDock.padding, bounds.width, max(0, bounds.height - ChatListFolderDock.padding * 2))
    }

    func set(folders: [(folder: ChatListFilter, unreadCount: Int, hasUnmutedUnread: Bool)], invoke: @escaping (ChatListFilter) -> Void) {
        table.removeAll()
        let size = NSMakeSize(max(bounds.width, 90), ChatListFolderDock.rowHeight)
        for (i, entry) in folders.enumerated() {
            let item = ChatListFolderColumnItem(size, stableId: AnyHashable(i), folder: entry.folder, selected: false, unreadCount: entry.unreadCount, hasUnmutedUnread: entry.hasUnmutedUnread, invoke: { invoke(entry.folder) })
            _ = table.addItem(item: item)
        }
        rowCount = folders.count
        isHidden = folders.isEmpty
    }
}
