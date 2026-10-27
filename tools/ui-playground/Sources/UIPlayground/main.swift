import AppKit

enum Folders { case sidebar, top }

struct Options {
    var folders: Folders = .sidebar
    var foldersHidden = false
    var dark = false
    var finder = false
    var compact = false
    var mode = "merged"
    var output: String?

    init() {
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--top": folders = .top
            case "--hidden": foldersHidden = true
            case "--dark": dark = true
            case "--finder": finder = true
            case "--compact": compact = true; finder = true
            case "--mode": mode = iterator.next() ?? "merged"
            case "--out": output = iterator.next()
            default: break
            }
        }
    }
}

let options = Options()

final class Palette {
    let background: NSColor
    let window: NSColor
    let text: NSColor
    let icon: NSColor
    let accent = NSColor(calibratedRed: 0.2, green: 0.55, blue: 0.95, alpha: 1)
    init(dark: Bool) {
        background = dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 1, alpha: 1)
        window = dark ? NSColor(white: 0.08, alpha: 1) : NSColor(white: 0.93, alpha: 1)
        text = dark ? .white : .black
        icon = dark ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.5, alpha: 1)
    }
}
let palette = Palette(dark: options.dark)

func burgerImage(color: NSColor) -> NSImage {
    let size = NSMakeSize(20, 14)
    return NSImage(size: size, flipped: false) { _ in
        color.setFill()
        for index in 0 ..< 3 {
            NSBezierPath(roundedRect: NSMakeRect(0, CGFloat(index) * 6, size.width, 2), xRadius: 1, yRadius: 1).fill()
        }
        return true
    }
}

func gearImage(color: NSColor) -> NSImage {
    let size = NSMakeSize(22, 22)
    return NSImage(size: size, flipped: false) { rect in
        color.setStroke()
        color.setFill()
        let center = NSMakePoint(rect.midX, rect.midY)
        for index in 0 ..< 8 {
            let angle = CGFloat(index) * .pi / 4
            let tooth = NSBezierPath()
            tooth.lineWidth = 3
            tooth.move(to: NSMakePoint(center.x + cos(angle) * 7, center.y + sin(angle) * 7))
            tooth.line(to: NSMakePoint(center.x + cos(angle) * 10, center.y + sin(angle) * 10))
            tooth.stroke()
        }
        let ring = NSBezierPath(ovalIn: NSMakeRect(center.x - 7, center.y - 7, 14, 14))
        ring.lineWidth = 2.5
        ring.stroke()
        return true
    }
}

extension NSImage {
    func tinted(_ color: NSColor) -> NSImage {
        let image = copy() as! NSImage
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

func label(_ text: String, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    return field
}

func folderColumn(height: CGFloat) -> NSView {
    let view = FlippedView(frame: NSMakeRect(0, 0, 90, height))
    let names = ["All", "Work", "Personal", "Bots", "Groups", "News"]
    for (index, name) in names.enumerated() {
        let y = 16 + CGFloat(index) * 62
        let icon = NSView(frame: NSMakeRect(33, y, 24, 24))
        icon.wantsLayer = true
        icon.layer?.backgroundColor = (index == 0 ? palette.accent : palette.icon).cgColor
        icon.layer?.cornerRadius = 6
        view.addSubview(icon)
        let text = label(name, size: 11, color: index == 0 ? palette.accent : palette.icon)
        text.sizeToFit()
        text.setFrameOrigin(NSMakePoint((90 - text.frame.width) / 2, y + 30))
        view.addSubview(text)
    }
    return view
}

func chatColumn(height: CGFloat, hasFolders: Bool) -> NSView {
    let view = FlippedView(frame: NSMakeRect(0, 0, 90, height))
    view.wantsLayer = true
    view.layer?.backgroundColor = palette.background.cgColor
    let colors: [NSColor] = [.systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemPink, .systemTeal, .systemIndigo]
    let stripHeight: CGFloat = hasFolders ? 108 : 64
    for index in 0 ..< 7 where 16 + CGFloat(index) * 66 + 50 <= height - stripHeight {
        let avatar = NSView(frame: NSMakeRect(20, 16 + CGFloat(index) * 66, 50, 50))
        avatar.wantsLayer = true
        avatar.layer?.backgroundColor = colors[index].cgColor
        avatar.layer?.cornerRadius = 25
        view.addSubview(avatar)
    }
    let strip = NSView(frame: NSMakeRect(0, height - stripHeight, 90, stripHeight))
    strip.wantsLayer = true
    strip.layer?.backgroundColor = palette.background.cgColor
    view.addSubview(strip)
    let gear = NSButton(frame: NSMakeRect(23, height - 56, 44, 44))
    gear.isBordered = false
    gear.image = gearImage(color: palette.icon)
    view.addSubview(gear)
    if hasFolders {
        let burger = NSButton(frame: NSMakeRect(23, height - 100, 44, 44))
        burger.isBordered = false
        burger.image = burgerImage(color: palette.icon)
        view.addSubview(burger)
    }
    return view
}

func finderSidebar(height: CGFloat) -> NSView {
    let effect = NSVisualEffectView(frame: NSMakeRect(0, 0, 270, height))
    effect.material = .sidebar
    effect.blendingMode = .behindWindow
    effect.state = .active
    let content = FlippedView(frame: effect.bounds)
    effect.addSubview(content)
    var y: CGFloat = 52
    func header(_ text: String) {
        let field = label(text, size: 11, color: .secondaryLabelColor, weight: .semibold)
        field.setFrameOrigin(NSMakePoint(18, y))
        field.sizeToFit()
        content.addSubview(field)
        y += 22
    }
    func row(_ title: String, subtitle: String? = nil, symbol: NSColor, selected: Bool = false, badge: String? = nil, avatar: Bool = false) {
        let rowHeight: CGFloat = avatar ? 48 : 28
        if selected {
            let box = NSView(frame: NSMakeRect(10, y, 250, rowHeight))
            box.wantsLayer = true
            box.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
            box.layer?.cornerRadius = 8
            content.addSubview(box)
        }
        let side: CGFloat = avatar ? 36 : 18
        let icon = NSView(frame: NSMakeRect(20, y + (rowHeight - side) / 2, side, side))
        icon.wantsLayer = true
        icon.layer?.backgroundColor = symbol.cgColor
        icon.layer?.cornerRadius = avatar ? side / 2 : 5
        content.addSubview(icon)
        let name = label(title, size: 13, color: .labelColor, weight: avatar ? .medium : .regular)
        name.sizeToFit()
        name.setFrameOrigin(NSMakePoint(avatar ? 66 : 48, y + (avatar ? 6 : 5)))
        content.addSubview(name)
        if let subtitle = subtitle {
            let sub = label(subtitle, size: 12, color: .secondaryLabelColor)
            sub.sizeToFit()
            sub.setFrameOrigin(NSMakePoint(66, y + 25))
            content.addSubview(sub)
        }
        if let badge = badge {
            let field = label(badge, size: 11, color: .white, weight: .semibold)
            field.sizeToFit()
            let pill = NSView(frame: NSMakeRect(238 - field.frame.width - 6, y + (rowHeight - 18) / 2, field.frame.width + 12, 18))
            pill.wantsLayer = true
            pill.layer?.backgroundColor = palette.accent.cgColor
            pill.layer?.cornerRadius = 9
            content.addSubview(pill)
            field.setFrameOrigin(NSMakePoint(pill.frame.minX + 6, pill.frame.minY + 1))
            content.addSubview(field)
        }
        y += rowHeight + 2
    }
    header("Folders")
    row("All Chats", symbol: .systemBlue, selected: true, badge: "12")
    row("Work", symbol: .systemOrange, badge: "3")
    row("Personal", symbol: .systemGreen)
    row("Bots", symbol: .systemPurple)
    row("Groups", symbol: .systemPink)
    y += 12
    header("Chats")
    let chats: [(String, String, NSColor)] = [("Anna", "see you tomorrow", .systemBlue), ("Design team", "Mike: new build is up", .systemOrange), ("Mom", "call me when free", .systemGreen), ("Spacegram", "Build 18 finished", .systemPurple), ("Saved Messages", "photo", .systemTeal)]
    for (index, chat) in chats.dropLast().enumerated() {
        row(chat.0, subtitle: chat.1, symbol: chat.2, badge: index == 1 ? "2" : nil, avatar: true)
    }
    let gear = NSButton(frame: NSMakeRect(14, height - 46, 36, 36))
    gear.isBordered = false
    gear.image = gearImage(color: .secondaryLabelColor)
    content.addSubview(gear)
    let burger = NSButton(frame: NSMakeRect(54, height - 46, 36, 36))
    burger.isBordered = false
    burger.image = burgerImage(color: .secondaryLabelColor)
    content.addSubview(burger)
    return effect
}

func compactFinderSidebar(height: CGFloat, showFolders: Bool = true, showChats: Bool = true) -> NSView {
    let width: CGFloat = 90
    let effect = NSVisualEffectView(frame: NSMakeRect(0, 0, width, height))
    effect.material = .sidebar
    effect.blendingMode = .behindWindow
    effect.state = .active
    let content = FlippedView(frame: effect.bounds)
    effect.addSubview(content)
    var y: CGFloat = 52
    let folders: [(String, NSColor, Bool, String?)] = [("All", .systemBlue, true, "12"), ("Work", .systemOrange, false, "3"), ("Personal", .systemGreen, false, nil), ("Bots", .systemPurple, false, nil)]
    for folder in folders where showFolders {
        if folder.2 {
            let box = NSView(frame: NSMakeRect(8, y - 4, width - 16, 52))
            box.wantsLayer = true
            box.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
            box.layer?.cornerRadius = 10
            content.addSubview(box)
        }
        let icon = NSView(frame: NSMakeRect((width - 24) / 2, y, 24, 24))
        icon.wantsLayer = true
        icon.layer?.backgroundColor = folder.1.cgColor
        icon.layer?.cornerRadius = 6
        content.addSubview(icon)
        let name = label(folder.0, size: 10, color: .labelColor)
        name.sizeToFit()
        name.setFrameOrigin(NSMakePoint((width - name.frame.width) / 2, y + 28))
        content.addSubview(name)
        if let badge = folder.3 {
            let field = label(badge, size: 9, color: .white, weight: .semibold)
            field.sizeToFit()
            let pill = NSView(frame: NSMakeRect(width / 2 + 6, y - 6, field.frame.width + 8, 14))
            pill.wantsLayer = true
            pill.layer?.backgroundColor = palette.accent.cgColor
            pill.layer?.cornerRadius = 7
            content.addSubview(pill)
            field.setFrameOrigin(NSMakePoint(pill.frame.minX + 4, pill.frame.minY))
            content.addSubview(field)
        }
        y += 56
    }
    if !showChats {
        let gear = NSButton(frame: NSMakeRect((width - 36) / 2, height - 50, 36, 36))
        gear.isBordered = false
        gear.image = gearImage(color: .secondaryLabelColor)
        content.addSubview(gear)
        return effect
    }
    if !showFolders { y = 52 }
    let line = NSView(frame: NSMakeRect(20, y + 2, width - 40, 1))
    line.isHidden = !showFolders
    line.wantsLayer = true
    line.layer?.backgroundColor = NSColor.separatorColor.cgColor
    content.addSubview(line)
    y += 14
    let colors: [NSColor] = [.systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemPink, .systemTeal, .systemIndigo]
    var index = 0
    while y + 50 <= height - 96 {
        let avatar = NSView(frame: NSMakeRect((width - 46) / 2, y, 46, 46))
        avatar.wantsLayer = true
        avatar.layer?.backgroundColor = colors[index % colors.count].cgColor
        avatar.layer?.cornerRadius = 23
        content.addSubview(avatar)
        y += 56
        index += 1
    }
    let gear = NSButton(frame: NSMakeRect((width - 36) / 2, height - 50, 36, 36))
    gear.isBordered = false
    gear.image = gearImage(color: .secondaryLabelColor)
    content.addSubview(gear)
    let burger = NSButton(frame: NSMakeRect((width - 36) / 2, height - 90, 36, 36))
    burger.isBordered = false
    burger.image = burgerImage(color: .secondaryLabelColor)
    burger.isHidden = !showFolders
    content.addSubview(burger)
    return effect
}

let size = NSMakeSize(720, 520)
let window = NSWindow(contentRect: NSMakeRect(200, 200, size.width, size.height), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "UIPlayground"
window.appearance = NSAppearance(named: options.dark ? .darkAqua : .aqua)
let content = FlippedView(frame: NSRect(origin: .zero, size: size))
content.wantsLayer = true
content.layer?.backgroundColor = palette.window.cgColor
window.contentView = content

var x: CGFloat = 0
let height = size.height - 28
if options.finder {
    let sideWidth: CGFloat = options.compact ? (options.mode == "two" ? 180 : 90) : 270
    let side: NSView
    if options.mode == "two" {
        side = NSView(frame: NSMakeRect(0, 0, 180, height))
        let folders = compactFinderSidebar(height: height, showFolders: true, showChats: false)
        let chats = compactFinderSidebar(height: height, showFolders: false, showChats: true)
        chats.setFrameOrigin(NSMakePoint(90, 0))
        side.addSubview(folders)
        side.addSubview(chats)
        let divider = NSView(frame: NSMakeRect(89, 0, 1, height))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        side.addSubview(divider)
    } else if options.mode == "chats" {
        side = compactFinderSidebar(height: height, showFolders: false, showChats: true)
    } else {
        side = options.compact ? compactFinderSidebar(height: height) : finderSidebar(height: height)
    }
    window.styleMask.insert(.fullSizeContentView)
    window.titlebarAppearsTransparent = true
    window.contentView = FlippedView(frame: NSRect(origin: .zero, size: size))
    let root = window.contentView!
    side.frame = NSMakeRect(0, 0, sideWidth, size.height)
    if options.mode != "two" { side.subviews[0].frame = side.bounds }
    root.addSubview(side)
    let chatArea = FlippedView(frame: NSMakeRect(sideWidth, 0, size.width - sideWidth, size.height))
    chatArea.wantsLayer = true
    chatArea.layer?.backgroundColor = palette.background.cgColor
    let hint = label("Select a chat", size: 14, color: palette.icon)
    hint.sizeToFit()
    hint.setFrameOrigin(NSMakePoint((chatArea.frame.width - hint.frame.width) / 2, size.height / 2))
    chatArea.addSubview(hint)
    root.addSubview(chatArea)
} else if options.folders == .sidebar && !options.foldersHidden {
    let column = folderColumn(height: height)
    column.setFrameOrigin(NSMakePoint(x, 0))
    content.addSubview(column)
    x += 90
}
if !options.finder {
let list = chatColumn(height: height, hasFolders: true)
list.setFrameOrigin(NSMakePoint(x, 0))
content.addSubview(list)
x += 90
}

let chat = FlippedView(frame: NSMakeRect(x, 0, size.width - x, height))
if !options.finder {
chat.wantsLayer = true
chat.layer?.backgroundColor = palette.background.cgColor
let title = label("Select a chat", size: 14, color: palette.icon)
title.sizeToFit()
title.setFrameOrigin(NSMakePoint((chat.frame.width - title.frame.width) / 2, height / 2))
chat.addSubview(title)
content.addSubview(chat)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + (options.output == nil ? 60 : 4)) {
    if options.finder, let output = options.output {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-o", "-l", String(window.windowNumber), output]
        try? task.run()
        task.waitUntilExit()
    } else if let output = options.output, let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
        content.cacheDisplay(in: content.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
    }
    app.terminate(nil)
}
app.run()
