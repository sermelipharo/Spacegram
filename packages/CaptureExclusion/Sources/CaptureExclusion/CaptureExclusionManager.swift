import Foundation
import AppKit
import ObjcUtils

public final class CaptureExclusionManager {

    public init() {
    }

    public struct Token: Hashable {
        public let id: UUID
        public init(id: UUID) {
            self.id = id
        }
    }

    private enum ExclusionSource {
        case fullWindow
        case view(WeakViewRef)
    }

    private struct ExclusionEntry {
        public let window: NSWindow
        public let source: ExclusionSource
    }

    private var entries: [Token: ExclusionEntry] = [:]
    private var windowTokens: [ObjectIdentifier: Set<Token>] = [:]
    private var trackedWindows: [ObjectIdentifier: WeakWindowRef] = [:]
    private var observations: [Token: [NSObjectProtocol]] = [:]

    public func addExclusion(for window: NSWindow) -> Token {
        let token = Token(id: UUID())
        let entry = ExclusionEntry(window: window, source: .fullWindow)
        insertEntry(token, entry: entry)
        reapply(for: window)
        return token
    }

    public func addExclusion(for window: NSWindow, view: NSView) -> Token {
        let token = Token(id: UUID())
        let entry = ExclusionEntry(window: window, source: .view(WeakViewRef(view)))
        insertEntry(token, entry: entry)

        var observers: [NSObjectProtocol] = []
        let reapplyBlock: (Notification) -> Void = { [weak self, weak window] _ in
            guard let window = window else { return }
            self?.reapply(for: window)
        }

        view.postsFrameChangedNotifications = true
        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: view,
            queue: .main,
            using: reapplyBlock
        ))

        if let scrollView = view.enclosingScrollView {
            observers.append(NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main,
                using: reapplyBlock
            ))
            observers.append(NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView.contentView,
                queue: .main,
                using: reapplyBlock
            ))
        }

        if let superview = view.superview {
            superview.postsFrameChangedNotifications = true
            observers.append(NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: superview,
                queue: .main,
                using: reapplyBlock
            ))
        }

        observations[token] = observers
        reapply(for: window)
        return token
    }

    public func forceReapply(for window: NSWindow) {
        DispatchQueue.main.async {
            self.reapply(for: window)
        }
    }

    public func removeExclusion(_ token: Token, for window: NSWindow) {
        guard entries.removeValue(forKey: token) != nil else { return }
        removeObservers(for: token)

        let key = ObjectIdentifier(window)
        windowTokens[key]?.remove(token)
        if windowTokens[key]?.isEmpty == true {
            windowTokens.removeValue(forKey: key)
            trackedWindows.removeValue(forKey: key)
            DispatchQueue.main.async {
                setWindowCaptureExclusion(window, .zero, false)
            }
        } else {
            reapply(for: window)
        }
    }

    public func cleanup() {
        for (_, weakRef) in trackedWindows {
            if let window = weakRef.window {
                DispatchQueue.main.async {
                    setWindowCaptureExclusion(window, .zero, false)
                }
            }
        }
        for token in observations.keys {
            removeObservers(for: token)
        }
        entries.removeAll()
        windowTokens.removeAll()
        trackedWindows.removeAll()
        observations.removeAll()
    }

    private func insertEntry(_ token: Token, entry: ExclusionEntry) {
        entries[token] = entry
        let key = ObjectIdentifier(entry.window)
        if windowTokens[key] == nil {
            windowTokens[key] = []
            trackedWindows[key] = WeakWindowRef(entry.window)
        }
        windowTokens[key]!.insert(token)
    }

    private func reapply(for window: NSWindow) {
    }

    private func removeObservers(for token: Token) {
        if let tokenObservers = observations.removeValue(forKey: token) {
            for observer in tokenObservers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

private final class WeakWindowRef {
    public weak var window: NSWindow?
    public init(_ window: NSWindow) { self.window = window }
}

private final class WeakViewRef {
    public weak var view: NSView?
    public init(_ view: NSView) { self.view = view }
}
