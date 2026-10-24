import AppKit
import TGUIKit

final class ChatHeaderDescriptionView: Control {
    private let textView = TextView()
    private var fullText = ""
    private var textColor: NSColor?

    var hasContent: Bool { !fullText.isEmpty }

    required init(frame: NSRect) {
        super.init(frame: frame)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        textView.isAccessibilityDecorative = true
        addSubview(textView)
        scaleOnClick = true
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(text: String?, theme: PresentationTheme) {
        let value = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard fullText != value || textColor != theme.colors.grayText else { return }
        fullText = value
        textColor = theme.colors.grayText
        toolTip = value.isEmpty ? nil : value
        setAccessibilityLabel(value)
        let preview = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let layout = TextViewLayout(.initialize(string: preview, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        layout.measure(width: max(0, frame.width - 24))
        textView.update(layout)
        needsLayout = true
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        update(text: fullText, theme: theme)
    }

    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let layout = textView.textLayout {
            layout.measure(width: max(0, size.width - 24))
            textView.update(layout)
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: 12))
        }
    }
}
