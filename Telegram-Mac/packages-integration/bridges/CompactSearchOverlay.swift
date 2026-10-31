import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import ChatUI
import ChatListUI
import TelegramUtils

extension Notification.Name {
    static let spacegramCompactSearch = Notification.Name("spacegramCompactSearch")
}

final class CompactSearchOverlay: NSView {
    private let context: AccountContext
    private let searchView = SearchView(frame: .zero)
    private let resultsHost = NSView()
    private let previewHost = NSView()
    private let bar = NSView()
    private let barTitle = TextView()
    private let openButton = TextButton()
    private let separator = NSView()
    private let titleDisposable = MetaDisposable()
    private var results: SearchController<AccountContext>?
    private var chat: ChatController?
    private var currentPeerId: PeerId?
    var onClose: (() -> Void)?

    private let headerHeight: CGFloat = 52
    private let barHeight: CGFloat = 40

    override var isFlipped: Bool { true }

    init(context: AccountContext, frame: NSRect) {
        self.context = context
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = theme.colors.background.cgColor
        addSubview(resultsHost)
        addSubview(bar)
        addSubview(previewHost)
        addSubview(searchView)
        addSubview(separator)
        bar.wantsLayer = true
        bar.layer?.backgroundColor = theme.colors.grayBackground.cgColor
        separator.wantsLayer = true
        separator.layer?.backgroundColor = theme.colors.border.cgColor
        barTitle.userInteractionEnabled = false
        barTitle.isSelectable = false
        bar.addSubview(barTitle)
        openButton.set(font: .medium(.text), for: .Normal)
        openButton.set(color: theme.colors.accent, for: .Normal)
        openButton.set(text: "Open chat ↗", for: .Normal)
        openButton.setFrameSize(NSMakeSize(120, 28))
        openButton.set(handler: { [weak self] _ in
            self?.openFullChat()
        }, for: .Click)
        bar.addSubview(openButton)
        bar.isHidden = true

        searchView.searchInteractions = SearchInteractions({ [weak self] state, _ in
            if state.state == .None {
                self?.close()
            }
        }, { [weak self] state in
            self?.results?.request(with: state.request)
        })

        let controller = SearchController<AccountContext>(context: context, open: { [weak self] id, messageId, _ in
            if let id = id, case let .chatId(_, peerId, _) = id {
                self?.showPreview(peerId: peerId, messageId: messageId)
            }
        }, options: [.chats, .messages], frame: NSMakeRect(0, 0, 100, 100))
        controller.navigationController = context.bindings.rootNavigation()
        results = controller
        needsLayout = true
        layout()
        controller.loadViewIfNeeded(resultsHost.bounds)
        controller.view.autoresizingMask = [.width, .height]
        resultsHost.addSubview(controller.view)
        controller.viewWillAppear(false)
        controller.viewDidAppear(false)
        searchView.change(state: .Focus, false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let rest = max(0, bounds.height - headerHeight - barHeight)
        let resultsHeight = floor(rest * 0.42)
        searchView.frame = NSMakeRect(12, 8, max(0, w - 24), 36)
        separator.frame = NSMakeRect(0, headerHeight - 1, w, 1)
        resultsHost.frame = NSMakeRect(0, headerHeight, w, resultsHeight)
        bar.frame = NSMakeRect(0, headerHeight + resultsHeight, w, barHeight)
        previewHost.frame = NSMakeRect(0, headerHeight + resultsHeight + barHeight, w, max(0, bounds.height - headerHeight - resultsHeight - barHeight))
        openButton.setFrameOrigin(NSMakePoint(w - openButton.frame.width - 12, floor((barHeight - openButton.frame.height) / 2)))
        barTitle.setFrameOrigin(NSMakePoint(16, floor((barHeight - barTitle.frame.height) / 2)))
    }

    private func closePreview() {
        if let chat = chat {
            chat.saveScrollStateNow()
            chat.viewWillDisappear(false)
            chat.view.removeFromSuperview()
            chat.viewDidDisappear(false)
        }
        chat = nil
    }

    private func showPreview(peerId: PeerId, messageId: MessageId?) {
        if currentPeerId == peerId, messageId == nil, chat != nil {
            return
        }
        closePreview()
        currentPeerId = peerId
        let controller = ChatController(context: context, chatLocation: .peer(peerId), focusTarget: ChatFocusTarget(messageId: messageId))
        controller.navigationController = context.bindings.rootNavigation()
        controller.loadViewIfNeeded(previewHost.bounds)
        controller.view.frame = previewHost.bounds
        controller.view.autoresizingMask = [.width, .height]
        previewHost.addSubview(controller.view)
        controller.viewWillAppear(false)
        controller.viewDidAppear(false)
        chat = controller
        bar.isHidden = false
        titleDisposable.set((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self = self else { return }
            let layout = TextViewLayout(.initialize(string: peer?._asPeer().displayTitle ?? "", color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .end)
            layout.measure(width: max(0, self.bar.frame.width - self.openButton.frame.width - 40))
            self.barTitle.update(layout)
            self.needsLayout = true
        }))
    }

    private func openFullChat() {
        guard let peerId = currentPeerId else {
            return
        }
        let navigation = context.bindings.rootNavigation()
        closePreview()
        close()
        navigation.push(ChatController(context: context, chatLocation: .peer(peerId)))
    }

    func close() {
        guard onClose != nil else {
            return
        }
        let callback = onClose
        onClose = nil
        closePreview()
        titleDisposable.dispose()
        if let results = results {
            results.viewWillDisappear(false)
            results.view.removeFromSuperview()
            results.viewDidDisappear(false)
        }
        results = nil
        removeFromSuperview()
        callback?()
    }
}
