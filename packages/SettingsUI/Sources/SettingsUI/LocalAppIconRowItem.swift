import Cocoa
import TGUIKit
import GeneralRows
import Localization
import TelegramTheme

public final class LocalAppIconRowItem: GeneralRowItem {
    static let iconSize = NSMakeSize(60, 70)
    static let perRow = 5

    public init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType) {
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }

    public override func viewClass() -> AnyClass {
        return LocalAppIconRowView.self
    }

    public override var accessibilityLabel: String? {
        return strings().appearanceSettingsDockIcon
    }

    var contentSize: NSSize {
        let rows = (LocalAppIcons.names.count + LocalAppIconRowItem.perRow - 1) / LocalAppIconRowItem.perRow
        return NSMakeSize(CGFloat(LocalAppIconRowItem.perRow) * LocalAppIconRowItem.iconSize.width, CGFloat(rows) * LocalAppIconRowItem.iconSize.height)
    }

    public override var height: CGFloat {
        return contentSize.height + 40
    }
}

private final class LocalAppIconControl: Control {
    let name: String
    private let content = SimpleLayer()
    private let outline = SimpleLayer()

    init(name: String) {
        self.name = name
        super.init(frame: LocalAppIconRowItem.iconSize.bounds)
        content.frame = NSMakeRect(0, 0, 60, 60)
        content.contentsGravity = .resizeAspect
        content.contentsScale = System.backingScale
        outline.frame = content.frame.insetBy(dx: 1, dy: 1)
        outline.cornerRadius = 14
        outline.borderWidth = 2
        outline.opacity = 0
        layer?.addSublayer(content)
        layer?.addSublayer(outline)
        if let path = LocalAppIcons.path(name), let image = NSImage(contentsOfFile: path) {
            content.contents = image._cgImage
        }
        setAccessibilityLabel(name)
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(selected: Bool) {
        outline.borderColor = theme.colors.accent.cgColor
        outline.opacity = selected ? 1 : 0
    }
}

private final class LocalAppIconRowView: GeneralContainableRowView {
    private var controls: [LocalAppIconControl] = []

    override func layout() {
        super.layout()
        guard let item = item as? LocalAppIconRowItem else {
            return
        }
        let origin = NSMakePoint(floor((containerView.frame.width - item.contentSize.width) / 2), 20)
        for (index, control) in controls.enumerated() {
            let row = index / LocalAppIconRowItem.perRow
            let column = index % LocalAppIconRowItem.perRow
            control.setFrameOrigin(NSMakePoint(origin.x + CGFloat(column) * LocalAppIconRowItem.iconSize.width, origin.y + CGFloat(row) * LocalAppIconRowItem.iconSize.height))
        }
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        if controls.isEmpty {
            for name in LocalAppIcons.names {
                let control = LocalAppIconControl(name: name)
                control.set(handler: { [weak self] control in
                    guard let control = control as? LocalAppIconControl else {
                        return
                    }
                    LocalAppIcons.select(control.name)
                    self?.updateSelection()
                }, for: .Click)
                containerView.addSubview(control)
                controls.append(control)
            }
        }
        updateSelection()
        needsLayout = true
    }

    private func updateSelection() {
        let selected = LocalAppIcons.selected
        for control in controls {
            control.update(selected: control.name == selected)
        }
    }
}
