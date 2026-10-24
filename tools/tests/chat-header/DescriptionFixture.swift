import AppKit
import TGUIKit
import ColorPalette

func runNativeDescriptionChecks() {
    let before = checks
    let fixture = ChatHeaderBubblesView()
    fixture.displaysPeerDescription = true
    let peer = ChatPresentationInterfaceState.PeerFixture(restriction: nil, isChannel: true)
    var presentation = ChatPresentationInterfaceState(peer: peer)
    presentation.cachedData = CachedChannelData(about: "  Team updates\nUseful links  ")
    fixture.updatePeerDescription(presentation)
    check(fixture.descriptionView.hasContent, "channel description was discarded")
    check(fixture.descriptionView.toolTip == "Team updates\nUseful links", "full description tooltip was lost")
    let text = fixture.descriptionView.subviews.compactMap { $0 as? TextView }.first!
    check(text.textLayout?.attributedString.string == "Team updates Useful links", "description did not form a single-line preview")
    check(fixture.descriptionView.accessibilityLabel() == "Team updates\nUseful links", "description was not exposed to accessibility")

    for state in [HeaderState(), HeaderState(main: .pinned(1)), HeaderState(main: .search(0, nil, nil, nil, nil, 0)), HeaderState(voiceChat: true), HeaderState(botManager: true), HeaderState(botAd: .init(height: 50)), HeaderState(monoforumHorizontal: true)] {
        fixture.displaysPeerDescription = state.canDisplayPeerDescription
        let frame = fixture.peerDescriptionFrame(for: 1100)
        check((frame != nil) == (state.main.stableFixtureId == 0 && state.height == 0), "description replaced another header row")
    }
    fixture.displaysPeerDescription = true
    for width: CGFloat in [350, 520, 650, 800, 1100] {
        let rect = fixture.peerDescriptionFrame(for: width)
        check(rect == fixture.inlineHeaderFrame(for: width), "description used a different slot than search and pinned messages")
        if let rect {
            fixture.descriptionView.frame = rect
            fixture.descriptionView.isHidden = false
            fixture.descriptionView.updateLayout(size: rect.size, transition: .immediate)
            check(text.frame.minX == 12 && text.frame.maxX <= rect.width - 12, "description escaped its horizontal padding")
            check(text.frame.minY >= 0 && text.frame.maxY <= rect.height, "description escaped the header height")
            check(fixture.descriptionView.hitTest(rect.center) === fixture.descriptionView, "description did not receive its own clicks")
        }
    }
    fixture.menuMode = .done
    check(fixture.peerDescriptionFrame(for: 1100) == nil, "description remained in selection mode")
    fixture.menuMode = .menu
    var opens = 0
    fixture.titleHandler = { opens += 1 }
    fixture.descriptionView.send(event: .Click)
    check(opens == 1, "description did not open the existing peer-info action")

    for value in [nil, "", " \t\r\n"] as [String?] {
        presentation.cachedData = CachedGroupData(about: value)
        fixture.updatePeerDescription(presentation)
        check(!fixture.descriptionView.hasContent && fixture.peerDescriptionFrame(for: 1100) == nil, "empty description created a blank pill")
    }
    presentation.cachedData = CachedGroupData(about: "A new group description")
    presentation.peer = .init(restriction: nil, isGroup: true)
    fixture.updatePeerDescription(presentation)
    check(fixture.descriptionView.hasContent, "basic-group description was lost")
    fixture.peerView = PeerView(cachedData: CachedChannelData(about: "Latest peer-view description"), peer: peer)
    fixture.updatePeerDescription(presentation)
    check(fixture.descriptionView.toolTip == "Latest peer-view description", "cached-data update showed the previous description")
    fixture.peerView = PeerView(cachedData: CachedChannelData(about: nil), peer: peer)
    fixture.updatePeerDescription(presentation)
    check(!fixture.descriptionView.hasContent, "deleted description reappeared from stale presentation data")
    fixture.peerView = nil

    for invalid in 0..<5 {
        var state = presentation
        if invalid == 0 { state.peer = .init(restriction: nil) }
        if invalid == 1 { state.peer = .init(restriction: "Restricted", isChannel: true) }
        if invalid == 2 { state.isNotAccessible = true }
        if invalid == 3 { state.isMonoforum = true }
        fixture.chatInteraction.mode = invalid == 4 ? .preview : .history
        fixture.updatePeerDescription(state)
        check(!fixture.descriptionView.hasContent, "description was shown for an ineligible chat")
    }
    fixture.chatInteraction.mode = .history
    let baseTheme = PresentationTheme.current
    for palette in [whitePalette, darkPalette] {
        fixture.currentChatTheme = PresentationTheme(colors: palette, search: baseTheme.search, inputTheme: baseTheme.inputTheme)
        presentation.cachedData = CachedChannelData(about: String(repeating: "👩🏽‍💻 مرحبا Project updates  ", count: 100))
        fixture.updatePeerDescription(presentation)
        fixture.descriptionView.frame = NSMakeRect(0, 0, 320, 40)
        fixture.descriptionView.updateLayout(size: NSMakeSize(320, 40), transition: .immediate)
        check(text.frame.width <= 296 && text.frame.height <= 40, "long localized description did not truncate")
        let color = text.textLayout!.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        check(color == palette.grayText, "description did not follow the chat palette")
    }
    appAppearance.languageCode = "ru-RU"
    let interaction = ChatInteraction()
    interaction.presentation.translateState = .init()
    let languages = chatTranslationMenuItem(chatInteraction: interaction)!.submenu!.items.first { $0.title == "Translate to" }!.submenu!
    check(languages.items.first?.title == "Russian", "upstream regional-language normalization regressed")
    appAppearance.languageCode = "ru"
    print("PASS: \(checks - before) native description eligibility, metadata, layout, palette and callback checks")
    renderHeaderComparisons()
}

extension HeaderState.Value {
    var stableFixtureId: Int {
        if case .none = self { return 0 }
        return 1
    }
}

private final class SnapshotCanvas: NSView {
    var fill = NSColor.black
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { fill.setFill(); bounds.fill() }
}

private final class SnapshotPill: NSView {
    var fill = NSColor.gray
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 20, yRadius: 20).fill()
    }
}

func renderHeaderComparisons() {
    let snapshotPath: String? = __SNAPSHOT_PATH__
    guard let path = snapshotPath else { return }
    let base = PresentationTheme.current
    func label(_ text: String, frame: CGRect, color: NSColor, size: CGFloat = 13) -> NSTextField {
        let view = NSTextField(labelWithString: text)
        view.frame = frame
        view.font = NSFont.systemFont(ofSize: size)
        view.textColor = color
        view.lineBreakMode = .byTruncatingTail
        return view
    }
    for (name, palette) in [("dark", nightAccentPalette), ("light", whitePalette)] {
        let searchTheme = SearchTheme(palette.grayBackground, NSImage(named: "Icon_SearchField")!.precomposed(palette.grayText), NSImage(named: "Icon_SearchClear")!.precomposed(palette.grayText), { "Search" }, palette.text, palette.grayText)
        let theme = PresentationTheme(colors: palette, search: searchTheme, inputTheme: base.inputTheme)
        updateTheme(theme)
        for after in [false, true] {
            let window = NSWindow(contentRect: NSMakeRect(-4000, -4000, 1000, 360), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let root = SnapshotCanvas(frame: NSMakeRect(0, 0, 1000, 360))
            root.fill = palette.background
            window.contentView = root
            for (index, scenario) in ["Pinned message", "Search", "No pinned message"].enumerated() {
                let y = CGFloat(index) * 120
                root.addSubview(label(scenario, frame: NSMakeRect(12, y, 400, 18), color: palette.grayText, size: 11))
                let geometry = ChatHeaderBubblesView()
                let inline = geometry.inlineHeaderFrame(for: 1000)!.offsetBy(dx: 0, dy: y + 10)
                let titleWidth = after ? inline.minX - 22 : 878
                let title = SnapshotPill(frame: NSMakeRect(12, y + 22, titleWidth, 40))
                title.fill = palette.grayBackground
                let avatar = SnapshotPill(frame: NSMakeRect(4, 4, 32, 32))
                avatar.fill = palette.accent
                avatar.addSubview(label("P", frame: NSMakeRect(10, 6, 18, 22), color: palette.underSelectedColor, size: 16))
                title.addSubview(avatar)
                title.addSubview(label("Project Updates", frame: NSMakeRect(44, 3, titleWidth - 58, 18), color: palette.text, size: 14))
                title.addSubview(label("14 members", frame: NSMakeRect(44, 21, titleWidth - 58, 16), color: palette.grayText, size: 12))
                root.addSubview(title)
                let actions = SnapshotPill(frame: NSMakeRect(900, y + 22, 88, 40))
                actions.fill = palette.grayBackground
                for (x, name) in [(CGFloat(4), "Icon_SearchField"), (CGFloat(44), "Icon_ChatActions")] {
                    let button = ImageButton()
                    button.set(image: NSImage(named: name)!.precomposed(palette.text), for: .Normal)
                    button.sizeToFit(.zero, NSMakeSize(40, 40), thatFit: true)
                    button.setFrameOrigin(NSMakePoint(x, 0))
                    actions.addSubview(button)
                }
                root.addSubview(actions)
                if index == 2 && !after { continue }
                let accessoryFrame = after ? inline : NSMakeRect(12, y + 72, 976, 40)
                let accessory = SnapshotPill(frame: accessoryFrame)
                accessory.fill = palette.grayBackground
                root.addSubview(accessory)
                if index == 0 {
                    accessory.addSubview(label("Pinned message", frame: NSMakeRect(14, 2, accessory.frame.width - 28, 18), color: palette.text))
                    accessory.addSubview(label("Project notes and useful links", frame: NSMakeRect(14, 21, accessory.frame.width - 28, 16), color: palette.grayText, size: 12))
                } else if index == 1 {
                    let search = NativeSearchFixture(frame: accessory.bounds)
                    search.from.isHidden = true
                    for (button, name, flipped) in [(search.prev, "Icon_SearchArrow", false), (search.next, "Icon_SearchArrow", true), (search.calendar, "Icon_Calendar", false), (search.cancel, "Icon_Pip_Close", false)] {
                        button.set(image: NSImage(named: name)!.precomposed(palette.text, flipVertical: flipped), for: .Normal)
                    }
                    accessory.addSubview(search)
                    search.updateLayout(size: search.frame.size, transition: .immediate)
                } else {
                    let description = ChatHeaderDescriptionView(frame: accessory.bounds)
                    description.update(text: "Announcements, project updates and useful links for the team.", theme: theme)
                    description.isHidden = false
                    accessory.addSubview(description)
                    description.updateLayout(size: description.frame.size, transition: .immediate)
                }
            }
            root.layoutSubtreeIfNeeded()
            window.display()
            let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
            root.cacheDisplay(in: root.bounds, to: rep)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path + "/" + name + (after ? "-after.png" : "-before.png")))
        }
    }
    updateTheme(base)
}
