import Foundation

struct Namespace: Equatable { let rawValue: Int }
enum Namespaces {
    enum Message { static let Cloud = Namespace(rawValue: 0) }
    enum Peer { static let SecretChat = Namespace(rawValue: 1) }
}
struct PeerId: Hashable {
    let value: Int
    var namespace: Namespace { Namespace(rawValue: 0) }
}
struct Peer {
    let id: PeerId
    let allowsReactions: Bool
}
struct EnginePeer { let peer: Peer; init(_ peer: Peer) { self.peer = peer } }
func canSendReactionsToPeer(_ peer: EnginePeer) -> Bool { peer.peer.allowsReactions }
struct MessageId { let peerId: PeerId; var namespace = Namespaces.Message.Cloud }
struct MessageFlags: OptionSet {
    let rawValue: Int
    static let ReactionsArePossible = MessageFlags(rawValue: 1)
    func contains(_ flag: MessageFlags) -> Bool { rawValue & flag.rawValue != 0 }
}
protocol Media {}
struct TelegramMediaAction: Media {}
struct TelegramMediaStory: Media { var isMention = false }
struct Message {
    var id = MessageId(peerId: PeerId(value: 2))
    var peers: [PeerId: Peer] = [:]
    var activeEphemeralReplacementMessage: Int?
    var adAttribute: Int?
    var containsSecretMedia = false
    var extendedMedia: Media?
    var flags: MessageFlags = []
}
struct Interaction { var peer: Peer?; var isPeerSavedMessages = false }
struct Entry { var isFakeMessage = false }
struct Row {
    var firstMessage: Message?
    var chatInteraction: Interaction
    var entry = Entry()
    var isUnsent = false
    var isFailed = false
    var unsupported = false
    var canReact: Bool { __CAN_REACT__ }
}
enum Reaction: Equatable {
    case builtin, stars
    func toUpdate(_ file: Int?) -> Int { 1 }
}
struct Source { var file: Int? }
struct Context { let peerId: PeerId }
enum Mode { case tag, full }
final class Engine {
    var calls = 0
    func sendStarsReaction(_ messageId: MessageId, count: Int) { calls += 1 }
    func react(_ messageId: MessageId, values: [Int]) { calls += 1 }
}
struct ChatHistoryUIHooks {
    static let shared = ChatHistoryUIHooks()
    func messageNewReactions(_ message: Message, _ update: Int, _ tags: Bool) -> [Int] { [update] }
}
func tap(message: Message, context: Context, mode: Mode, engine: Engine, value: Reaction = .builtin, isFilterTag: Bool = false, tagAction: (Reaction) -> Void = { _ in }) {
    let source = Source()
    __CHIP_ACTION__
}
var checks = 0
var failures = 0
func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(name)") }
}
let chatId = PeerId(value: 2)
let restricted = Peer(id: chatId, allowsReactions: false)
let allowed = Peer(id: chatId, allowsReactions: true)
var message = Message(peers: [chatId: restricted])
var row = Row(firstMessage: message, chatInteraction: Interaction(peer: restricted))
expect(!row.canReact, "restricted chat does not offer reaction picker or quick reaction")
row.chatInteraction.peer = allowed
expect(row.canReact, "current allowed rights supersede stale restricted message peer")
message.peers[chatId] = allowed
row.firstMessage = message
row.chatInteraction.peer = restricted
expect(!row.canReact, "current restriction supersedes stale allowed message peer")
row.chatInteraction.peer = nil
expect(row.canReact, "search history falls back to actual message peer")
row.chatInteraction.peer = Peer(id: PeerId(value: 3), allowsReactions: false)
expect(row.canReact, "unrelated presentation peer does not restrict message chat")
row.firstMessage?.peers = [:]
expect(!row.canReact, "unresolved chat permissions do not offer reactions")
row.chatInteraction.peer = allowed
row.firstMessage = message
row.isUnsent = true
expect(!row.canReact, "unsent message stays unavailable")
row.isUnsent = false
row.firstMessage?.containsSecretMedia = true
expect(!row.canReact, "secret media stays unavailable")
for value in [Reaction.builtin, .stars] {
    let engine = Engine()
    var restrictedMessage = message
    restrictedMessage.peers[chatId] = restricted
    tap(message: restrictedMessage, context: Context(peerId: PeerId(value: 1)), mode: .full, engine: engine, value: value)
    expect(engine.calls == 0, "existing restricted reaction chip never submits \(value)")
    engine.calls = 0
    tap(message: message, context: Context(peerId: PeerId(value: 1)), mode: .full, engine: engine, value: value)
    expect(engine.calls == 1, "allowed reaction chip submits \(value)")
}
let engine = Engine()
var filtered = false
tap(message: message, context: Context(peerId: chatId), mode: .tag, engine: engine, tagAction: { _ in filtered = true })
expect(filtered && engine.calls == 0, "saved-message tags still filter without submitting")
print("\(checks - failures)/\(checks) reaction permission checks passed")
exit(failures == 0 ? 0 : 1)
