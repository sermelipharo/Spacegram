import AppKit

enum Folders { case sidebar, top }

struct Options {
    var folders: Folders = .sidebar
    var foldersHidden = false
    var dark = false
    var output: String?

    init() {
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--top": folders = .top
            case "--hidden": foldersHidden = true
            case "--dark": dark = true
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
if options.folders == .sidebar && !options.foldersHidden {
    let column = folderColumn(height: height)
    column.setFrameOrigin(NSMakePoint(x, 0))
    content.addSubview(column)
    x += 90
}
let list = chatColumn(height: height, hasFolders: true)
list.setFrameOrigin(NSMakePoint(x, 0))
content.addSubview(list)
x += 90

let chat = FlippedView(frame: NSMakeRect(x, 0, size.width - x, height))
chat.wantsLayer = true
chat.layer?.backgroundColor = palette.background.cgColor
let title = label("Select a chat", size: 14, color: palette.icon)
title.sizeToFit()
title.setFrameOrigin(NSMakePoint((chat.frame.width - title.frame.width) / 2, height / 2))
chat.addSubview(title)
content.addSubview(chat)

let app = NSApplication.shared
app.setActivationPolicy(.regular)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + (options.output == nil ? 60 : 4)) {
    if let output = options.output, let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
        content.cacheDisplay(in: content.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
    }
    app.terminate(nil)
}
app.run()
