import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import InAppSettings
import Localization
import TelegramContext
import TelegramTheme
import TelegramUtils
import GeneralRows
import StoriesUI
import InlineStickerLayer

public class ChatListRevealItem: TableStickItem {
    fileprivate let action:((ChatListFilter)->Void)?
    fileprivate let context: (any AccountContextProtocol)?
    fileprivate let tabs: [ChatListFilter]
    fileprivate let selected: ChatListFilter
    fileprivate let openSettings: (()->Void)?
    fileprivate let counters: ChatListFilterBadges
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let _menuItems: ((ChatListFilter, Int?, Bool?)->[ContextMenuItem])?
    fileprivate let getCurrentStoriesState:()->(StoryListChatListRowItem.InterfaceState, NSView)?
    fileprivate let customBackgroundColor: NSColor?
    fileprivate let compactTabs: Bool
    fileprivate let favoriteTabIds: [Int32]?
    public init(_ initialSize: NSSize, context: any AccountContextProtocol, tabs: [ChatListFilter], selected: ChatListFilter, counters: ChatListFilterBadges, compactTabs: Bool = false, favoriteTabIds: [Int32]? = nil, action: ((ChatListFilter)->Void)? = nil, openSettings: (()->Void)? = nil, menuItems: ((ChatListFilter, Int?, Bool?)->[ContextMenuItem])? = nil, presentation: TelegramPresentationTheme = theme, customBackgroundColor: NSColor? = nil, getCurrentStoriesState:@escaping()->(StoryListChatListRowItem.InterfaceState, NSView)? = { return nil }) {
        self.action = action
        self.context = context
        self.tabs = tabs
        self.presentation = presentation
        self.selected = selected
        self.openSettings = openSettings
        self.counters = counters
        self._menuItems = menuItems
        self.customBackgroundColor = customBackgroundColor
        self.compactTabs = compactTabs
        self.favoriteTabIds = favoriteTabIds
        self.getCurrentStoriesState = getCurrentStoriesState
        super.init(initialSize)
    }

    public required init(_ initialSize: NSSize) {
        self.action = nil
        self.context = nil
        self.tabs = []
        self.presentation = theme
        self.selected = .allChats
        self.openSettings = nil
        self._menuItems = nil
        self.customBackgroundColor = nil
        self.compactTabs = false
        self.favoriteTabIds = nil
        self.getCurrentStoriesState = { return nil }
        self.counters = ChatListFilterBadges(total: 0, filters: [])
        super.init(initialSize)
    }


    public override var backdorColor: NSColor {
        return customBackgroundColor ?? .clear
    }

    public override var borderColor: NSColor {
        return .clear
    }

    public override var singletonItem: Bool {
        return false
    }
    
    public func menuItems(for item: ChatListFilter, unreadCount: Int?) -> Signal<[ContextMenuItem], NoError> {
        
        let id = ChatListUIHooks.shared.chatListFilterId(item)
        _ = self.context
        
        guard let context = self.context else {
            return .complete()
        }
        
        let filterPeersAreMuted: Signal<Bool, NoError> = context.engine.peers.currentChatListFilters()
        |> take(1)
        |> mapToSignal { filters -> Signal<Bool, NoError> in
            guard let filter = filters.first(where: { ChatListUIHooks.shared.chatListFilterId($0) == id }) else {
                return .single(false)
            }
            guard case let .filter(_, _, _, data) = filter else {
                return .single(false)
            }
            return context.engine.data.get(
                EngineDataList(data.includePeers.peers.map(TelegramEngine.EngineData.Item.Peer.NotificationSettings.init(id:)))
            )
            |> map { list -> Bool in
                for item in list {
                    switch item.muteState {
                    case .default, .unmuted:
                        return false
                    default:
                        break
                    }
                }
                return true
            }
        } |> deliverOnMainQueue
        
        return filterPeersAreMuted |> map { [weak self] allMuted in
            return self?._menuItems?(item, unreadCount, allMuted) ?? []
        }
    }
    
    public override var stableId: AnyHashable {
        return UIChatListEntryId.reveal
    }
    
    public override func viewClass() -> AnyClass {
        return ChatListRevealView.self
    }
    
    public override var identifier: String {
        return "ChatListRevealView"
    }
    
    public override var height: CGFloat {
        return 30
    }
    
    static func accessibilityTabTitle(_ title: String, unreadCount: Int?) -> String {
        if let count = unreadCount, count > 0 {
            return title + ", " + strings().voiceOverChatUnreadMessagesOther(count)
        }
        return title
    }

    func accessibilityTabTitle(_ tab: ChatListFilter) -> String {
        return ChatListRevealItem.accessibilityTabTitle(tab.title, unreadCount: counters.count(for: tab)?.count)
    }
    
    public override var accessibilityLabel: String? {
        return strings().chatListFilterListTitle
    }
    
    public override var accessibilityValue: String? {
        guard !tabs.isEmpty else {
            return nil
        }
        return accessibilityTabTitle(selected) + ", " + strings().voiceOverCommonSelected
    }
    
    public override var accessibilityRole: NSAccessibility.Role? {
        return .tabGroup
    }
    
    public override func accessibilityPerformPress() -> Bool {
        return false
    }
}


private final class FavoriteFolderTabButton: NSButton {
    private let textView = InteractiveTextView()
    private let badgeView = ImageView()
    private let selectionView = View()
    private let textLayout: TextViewLayout
    private let context: any AccountContextProtocol
    private let callback: () -> Void
    private let menuItems: () -> Signal<[ContextMenuItem], NoError>
    private let menuDisposable = MetaDisposable()
    let minimumWidth: CGFloat

    init(tab: ChatListFilter, selected: Bool, badge: CGImage?, context: any AccountContextProtocol, presentation: TelegramPresentationTheme, callback: @escaping () -> Void, menuItems: @escaping () -> Signal<[ContextMenuItem], NoError>) {
        self.context = context
        self.callback = callback
        self.menuItems = menuItems
        let text = NSMutableAttributedString()
        text.append(string: tab.title, color: selected ? presentation.colors.text : presentation.colors.grayText, font: .normal(.text))
        InlineStickerItem.apply(to: text, associatedMedia: [:], entities: tab.entities, isPremium: context.isPremium, playPolicy: tab.enableAnimations ? nil : .framesCount(1))
        textLayout = TextViewLayout(text, maximumNumberOfLines: 1)
        textLayout.measure(width: .greatestFiniteMagnitude)
        let badgeWidth = badge.map { $0.backingSize.width + 5 } ?? 0
        minimumWidth = min(120, max(64, ceil(textLayout.layoutSize.width + badgeWidth + 20)))
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
        target = self
        action = #selector(selectFolder)
        setAccessibilityLabel(tab.title)
        setAccessibilityValue(selected ? "1" : "0")
        textView.userInteractionEnabled = false
        textView.textView.isSelectable = false
        textView.isEventLess = true
        addSubview(textView)
        badgeView.image = badge
        badgeView.sizeToFit()
        badgeView.isEventLess = true
        badgeView.isHidden = badge == nil
        addSubview(badgeView)
        selectionView.backgroundColor = presentation.colors.accent
        selectionView.layer?.cornerRadius = 1.5
        selectionView.isEventLess = true
        selectionView.isHidden = !selected
        addSubview(selectionView)
    }

    override var isFlipped: Bool {
        return true
    }

    @objc private func selectFolder() {
        callback()
    }

    override func rightMouseDown(with event: NSEvent) {
        menuDisposable.set(menuItems().start(next: { [weak self] items in
            if let self = self {
                ContextMenu.show(items: items, view: self, event: event)
            }
        }))
    }

    override func layout() {
        super.layout()
        let badgeWidth = badgeView.isHidden ? 0 : badgeView.frame.width + 5
        textLayout.measure(width: max(0, bounds.width - badgeWidth - 20))
        textView.set(text: textLayout, context: context)
        let contentWidth = textView.frame.width + badgeWidth
        let textX = max(10, floor((bounds.width - contentWidth) / 2))
        textView.setFrameOrigin(NSMakePoint(textX, floor((bounds.height - textView.frame.height) / 2) - 2))
        badgeView.setFrameOrigin(NSMakePoint(textView.frame.maxX + 5, floor((bounds.height - badgeView.frame.height) / 2) - 2))
        selectionView.frame = NSMakeRect(8, max(0, bounds.height - 3), max(0, bounds.width - 16), 3)
    }

    deinit {
        menuDisposable.dispose()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class FavoriteFolderOverflowButton: NSButton {
    var makeMenu: (() -> NSMenu)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = "⋮"
        font = .systemFont(ofSize: 21, weight: .medium)
        isBordered = false
        setButtonType(.momentaryChange)
        target = self
        action = #selector(showFolders)
    }

    @objc private func showFolders() {
        makeMenu?().popUp(positioning: nil, at: NSMakePoint(0, bounds.height), in: self)
    }

    func updateColor(_ color: NSColor) {
        attributedTitle = NSAttributedString(string: "⋮", attributes: [.font: NSFont.systemFont(ofSize: 21, weight: .medium), .foregroundColor: color])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class FavoriteFolderMenuItem: NSMenuItem {
    private let callback: () -> Void

    init(title: String, callback: @escaping () -> Void) {
        self.callback = callback
        super.init(title: title, action: nil, keyEquivalent: "")
        target = self
        action = #selector(selectFolder)
    }

    @objc private func selectFolder() {
        callback()
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public final class ChatListRevealView : TableStickView {
    private let containerView = View()
    private let favoriteTabsView = View()
    private let overflowButton = FavoriteFolderOverflowButton(frame: .zero)
    private var favoriteButtons: [(Int32, FavoriteFolderTabButton)] = []
    private var favoriteLayout: FavoriteFolderTabLayout?
    private var animated: Bool = false
    public let segmentView: ScrollableSegmentView = ScrollableSegmentView(frame: NSZeroRect)
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.backgroundColor = .clear
        containerView.layer?.masksToBounds = false
        containerView.addSubview(segmentView)
        containerView.addSubview(favoriteTabsView)
        favoriteTabsView.backgroundColor = .clear
        favoriteTabsView.isHidden = true
        favoriteTabsView.addSubview(overflowButton)
        overflowButton.makeMenu = { [weak self] in
            return self?.favoriteFoldersMenu() ?? NSMenu()
        }
        segmentView.layer?.masksToBounds = true

        self.layer?.masksToBounds = false

        segmentView.scrollView.applyExternalScroll = { [weak self] event in
            if let item = self?.item as? ChatListRevealItem {
                if let (state, view) = item.getCurrentStoriesState() {
                    switch state {
                    case .progress:
                        view.scrollWheel(with: event)
                        return true
                    default:
                        return false
                    }
                }
            }
            return false
        }
    }

    public override func mouseUp(with event: NSEvent) {
       
    }
    public override func mouseDown(with event: NSEvent) {
        if mouseInside() {
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        if let item = item as? ChatListRevealItem, item.compactTabs, let (state, view) = item.getCurrentStoriesState(), case .progress = state {
            view.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    
    public override func updateIsVisible(_ visible: Bool, animated: Bool) {
        super.updateIsVisible(visible, animated: animated)
    }

    public override var backdorColor: NSColor {
        return (item as? ChatListRevealItem)?.customBackgroundColor ?? .clear
    }

    public override func updateColors() {
        super.updateColors()
        needsDisplay = true
    }
    
    private var splitViewState: SplitViewState?
    
    public override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)

        guard let item = item as? ChatListRevealItem else {
            return
        }

        var animated = (self.animated || animated)
        self.animated = true


        guard let context = item.context else {
            return
        }
        
        let generateIcon:(ChatListFilter?)->CGImage? = { tab in
            let unreadCount:ChatListFilterBadge? = item.counters.count(for: tab)
            let icon: CGImage?
            if let unreadCount = unreadCount, unreadCount.count > 0 {
                let attributedString = NSAttributedString.initialize(string: "\(unreadCount.count.prettyNumber)", color: item.presentation.colors.background, font: .medium(.short))
                let textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .start, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .center)
                var size = NSMakeSize(textLayout.0.size.width + 8, textLayout.0.size.height + 5)
                size = NSMakeSize(max(size.height,size.width), size.height)
                
                icon = generateImage(size, rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    if item.selected == tab || unreadCount.hasUnmutedUnread {
                        ctx.setFillColor(item.presentation.colors.accent.cgColor)
                    } else {
                        ctx.setFillColor(item.presentation.colors.badgeMuted.cgColor)
                    }
                    
                    
                    ctx.round(size, size.height/2.0)
                    ctx.fill(rect)
                    
                    let focus = rect.focus(textLayout.0.size)
                    textLayout.1.draw(focus.offsetBy(dx: 0, dy: -1), in: ctx, backingScaleFactor: 2.0, backgroundColor: .white)
                    
                })!
            } else if let _ = tab {
                icon = nil
            } else {
                icon = nil
            }
            return icon
        }
        
        animated = animated && splitViewState == context.layout
        self.splitViewState = context.layout

        segmentView.isHidden = item.compactTabs
        favoriteTabsView.isHidden = !item.compactTabs
        if item.compactTabs {
            updateFavoriteTabs(item: item, context: context, generateIcon: generateIcon)
            return
        }
        favoriteButtons.forEach { $0.1.removeFromSuperview() }
        favoriteButtons.removeAll()
        favoriteLayout = nil
        
        let segmentTheme = ScrollableSegmentTheme(background: .clear, border: item.presentation.colors.border, selector: item.presentation.colors.accent, inactiveText: item.presentation.colors.grayText, activeText: item.presentation.colors.text, textFont: .normal(.text))

        segmentView.theme = segmentTheme

        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10)
        var items:[ScrollableSegmentItem] = []
        for tab in item.tabs {
            let unreadCount = item.counters.count(for: tab)
            let icon: CGImage? = generateIcon(tab)
            let title: String = tab.title
            let selected = item.selected == tab

            let segmentItem = ScrollableSegmentItem(title: title, index: index, uniqueId: Int64(ChatListUIHooks.shared.chatListFilterId(tab)), selected: selected, insets: insets, icon: icon, theme: segmentTheme, equatable: UIEquatable(unreadCount), customTextView: {
                
                let attr = NSMutableAttributedString()
                attr.append(string: title, color: selected ? segmentTheme.activeText : segmentTheme.inactiveText, font: segmentTheme.textFont)
                InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: tab.entities, isPremium: context.isPremium, playPolicy: tab.enableAnimations ? nil : .framesCount(1))

                let layout = TextViewLayout(attr)
                layout.measure(width: .greatestFiniteMagnitude)

                let textView = InteractiveTextView()
                textView.userInteractionEnabled = false
                textView.textView.isSelectable = false
                textView.set(text: layout, context: context)
                
                return textView
            })
            let accessibilityUnreadCount = unreadCount?.count
            segmentItem.accessibilityLabel = {
                return ChatListRevealItem.accessibilityTabTitle(title, unreadCount: accessibilityUnreadCount)
            }
            items.append(segmentItem)
            index += 1
        }
        
        segmentView.updateItems(items, animated: animated)
        let range: NSRange
        if context.isPremium {
            range = NSMakeRange(0, items.count)
        } else {
            range = NSMakeRange(1, items.count - 1)
        }
        segmentView.resortRange = range
        segmentView.resortHandler = { from, to in
            _ = context.engine.peers.updateChatListFiltersInteractively({ state in
                var state = state
                if context.isPremium {
                    state.move(at: from, to: to)
                } else {
                    state.move(at: from - 1, to: to - 1)
                }
                return state
            }).start()
        }
        segmentView.didChangeSelectedItem = { [weak item] selected in
            if let item = item {
                if selected.uniqueId == -1 {
                    item.action?(.allChats)
                } else if selected.uniqueId == -2 {
                    item.openSettings?()
                } else {
                    item.action?(item.tabs[selected.index])
                }
            }
        }
        segmentView.menuItems = { [weak item] selected in
            if let item = item, selected.uniqueId != -1 && selected.uniqueId != -2 {
                return item.menuItems(for: item.tabs[selected.index], unreadCount: item.counters.count(for: item.tabs[selected.index])?.count)
            } else if let item = item, selected.uniqueId == -1 {
                return item.menuItems(for: .allChats, unreadCount: nil)
            } else {
                return .single([])
            }
        }
      
    }

    private func updateFavoriteTabs(item: ChatListRevealItem, context: any AccountContextProtocol, generateIcon: (ChatListFilter?) -> CGImage?) {
        favoriteButtons.forEach { $0.1.removeFromSuperview() }
        favoriteButtons.removeAll()
        var seenIds = Set<Int32>()
        for tab in item.tabs {
            let id = ChatListUIHooks.shared.chatListFilterId(tab)
            guard seenIds.insert(id).inserted else { continue }
            let button = FavoriteFolderTabButton(tab: tab, selected: item.selected == tab, badge: generateIcon(tab), context: context, presentation: item.presentation, callback: { [weak item] in
                item?.action?(tab)
            }, menuItems: { [weak item] in
                guard let item = item else { return .single([]) }
                return item.menuItems(for: tab, unreadCount: item.counters.count(for: tab)?.count)
            })
            favoriteTabsView.addSubview(button)
            favoriteButtons.append((id, button))
        }
        overflowButton.updateColor(item.presentation.colors.grayText)
        overflowButton.setAccessibilityLabel(strings().chatListFolderMoreFolders)
        needsLayout = true
        layoutFavoriteTabs()
    }

    private func layoutFavoriteTabs() {
        guard let item = item as? ChatListRevealItem, item.compactTabs else { return }
        let layout = FavoriteFolderTabLayout.make(tabs: favoriteButtons.map { .init(id: $0.0, minimumWidth: $0.1.minimumWidth) }, favoriteTabIds: item.favoriteTabIds, availableWidth: bounds.width)
        favoriteLayout = layout
        var x: CGFloat = 0
        let visible = Set(layout.visibleIds)
        for (id, button) in favoriteButtons {
            button.isHidden = !visible.contains(id)
            if !button.isHidden {
                button.frame = NSMakeRect(x, 0, layout.tabWidth, bounds.height)
                x += layout.tabWidth
            }
        }
        overflowButton.isHidden = layout.overflowWidth == 0
        overflowButton.frame = NSMakeRect(max(0, bounds.width - layout.overflowWidth), 0, layout.overflowWidth, bounds.height)
        let selectedId = ChatListUIHooks.shared.chatListFilterId(item.selected)
        overflowButton.updateColor(layout.overflowIds.contains(selectedId) ? item.presentation.colors.accent : item.presentation.colors.grayText)
    }

    private func favoriteFoldersMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        guard let item = item as? ChatListRevealItem, let layout = favoriteLayout else { return menu }
        let hidden = Set(layout.overflowIds)
        let selectFolder = item.action
        let openSettings = item.openSettings
        var seenIds = Set<Int32>()
        for tab in item.tabs where hidden.contains(ChatListUIHooks.shared.chatListFilterId(tab)) && seenIds.insert(ChatListUIHooks.shared.chatListFilterId(tab)).inserted {
            let count = item.counters.count(for: tab)?.count ?? 0
            let title = count > 0 ? "\(tab.title)   \(count.prettyNumber)" : tab.title
            let menuItem = FavoriteFolderMenuItem(title: title, callback: {
                selectFolder?(tab)
            })
            menuItem.state = item.selected == tab ? .on : .off
            menu.addItem(menuItem)
        }
        if !menu.items.isEmpty {
            menu.addItem(.separator())
        }
        menu.addItem(FavoriteFolderMenuItem(title: strings().chatListFolderFavoriteFolders, callback: {
            openSettings?()
        }))
        return menu
    }
    
    
    public override var isHidden: Bool {
        didSet {
            if isHidden {
                var bp:Int = 0
                bp += 1
            }
        }
    }
    
    public override var isAlwaysUp: Bool {
        return true
    }
    
    public override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
    public override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func layout() {
        super.layout()

        containerView.frame = bounds
        favoriteTabsView.frame = containerView.bounds
        layoutFavoriteTabs()
        segmentView.frame = NSMakeRect(0, -10, containerView.bounds.width, containerView.bounds.height
         + 10)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
