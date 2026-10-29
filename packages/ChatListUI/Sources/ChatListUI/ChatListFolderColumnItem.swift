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
    fileprivate let titleLayout: TextViewLayout
    fileprivate let countLayout: TextViewLayout?

    public init(_ initialSize: NSSize, stableId: AnyHashable, folder: ChatListFilter, selected: Bool, unreadCount: Int, hasUnmutedUnread: Bool, invoke: @escaping()->Void) {
        self.folder = folder
        self.isCurrentFolder = selected
        self.unreadCount = unreadCount
        self.hasUnmutedUnread = hasUnmutedUnread
        self.invoke = invoke
        self.titleLayout = TextViewLayout(.initialize(string: folder.title, color: selected ? theme.colors.accent : theme.colors.text, font: .medium(10)), maximumNumberOfLines: 1, truncationType: .end)
        if unreadCount > 0 {
            self.countLayout = TextViewLayout(.initialize(string: unreadCount.prettyNumber, color: .white, font: .medium(8)), maximumNumberOfLines: 1)
        } else {
            self.countLayout = nil
        }
        super.init(initialSize, stableId: stableId)
    }

    public override var height: CGFloat {
        return 30
    }

    public override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        countLayout?.measure(width: 24)
        titleLayout.measure(width: width - 4 - 2)
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

fileprivate final class ChatListFolderColumnView: TableRowView {
    private let plate = View()
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
        plate.addSubview(titleView)
        plate.addSubview(countBadge)
        plate.addSubview(countView)
        plate.addSubview(overlay)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        countView.userInteractionEnabled = false
        countView.isSelectable = false

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
        plate.frame = NSMakeRect(2, 1, frame.width - 4, frame.height - 2)
        overlay.frame = plate.bounds
        if !countView.isHidden {
            countBadge.frame = NSMakeRect(plate.frame.width - countView.frame.width - 10, 0, countView.frame.width + 8, 12)
            countBadge.layer?.cornerRadius = 6
            countView.setFrameOrigin(NSMakePoint(countBadge.frame.minX + 4, countBadge.frame.minY + floorToScreenPixels((12 - countView.frame.height) / 2)))
        }
        titleView.setFrameOrigin(NSMakePoint(floorToScreenPixels((plate.frame.width - titleView.frame.width) / 2), floorToScreenPixels((plate.frame.height - titleView.frame.height) / 2) + 2))
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ChatListFolderColumnItem else {
            return
        }
        plate.backgroundColor = item.isCurrentFolder ? theme.colors.accent.withAlphaComponent(0.14) : .clear
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

final class ChatListFolderDock: NSView {
    private let backdrop: NSView
    private var items: [ChatListFolderColumnItem] = []
    private var rows: [ChatListFolderColumnView] = []

    static let rowHeight: CGFloat = 30

    var rowCount: Int {
        return items.count
    }

    var contentHeight: CGFloat {
        return items.isEmpty ? 0 : CGFloat(items.count) * ChatListFolderDock.rowHeight + 4
    }

    override init(frame frameRect: NSRect) {
        if #available(macOS 26.0, *) {
            let container = NSView(frame: frameRect)
            let blur = NSVisualEffectView(frame: frameRect)
            blur.material = .hudWindow
            blur.blendingMode = .withinWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]
            container.addSubview(blur)
            let glass = NSGlassEffectView(frame: frameRect)
            glass.cornerRadius = 0
            glass.autoresizingMask = [.width, .height]
            container.addSubview(glass)
            backdrop = container
        } else {
            let effect = NSVisualEffectView(frame: frameRect)
            effect.material = .sidebar
            effect.blendingMode = .withinWindow
            effect.state = .active
            backdrop = effect
        }
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(backdrop)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        backdrop.frame = bounds
        for (i, row) in rows.enumerated() {
            _ = items[i].makeSize(bounds.width)
            row.frame = NSMakeRect(0, bounds.height - 2 - CGFloat(i + 1) * ChatListFolderDock.rowHeight, bounds.width, ChatListFolderDock.rowHeight)
            row.set(item: items[i])
        }
    }

    func set(folders: [(folder: ChatListFilter, unreadCount: Int, hasUnmutedUnread: Bool)], invoke: @escaping (ChatListFilter) -> Void) {
        rows.forEach { $0.removeFromSuperview() }
        let size = NSMakeSize(max(bounds.width, 66), ChatListFolderDock.rowHeight)
        items = folders.enumerated().map { i, entry in
            ChatListFolderColumnItem(size, stableId: AnyHashable(i), folder: entry.folder, selected: false, unreadCount: entry.unreadCount, hasUnmutedUnread: entry.hasUnmutedUnread, invoke: { invoke(entry.folder) })
        }
        rows = items.map { _ in ChatListFolderColumnView(frame: NSMakeRect(0, 0, size.width, size.height)) }
        rows.forEach { addSubview($0) }
        needsLayout = true
    }
}
