import Foundation

public struct FavoriteFolderTabLayout: Equatable {
    public struct Tab: Equatable {
        public let id: Int32
        public let minimumWidth: CGFloat

        public init(id: Int32, minimumWidth: CGFloat) {
            self.id = id
            self.minimumWidth = minimumWidth
        }
    }

    public let visibleIds: [Int32]
    public let overflowIds: [Int32]
    public let tabWidth: CGFloat
    public let overflowWidth: CGFloat

    public static func make(tabs: [Tab], favoriteTabIds: [Int32]?, availableWidth: CGFloat, overflowWidth: CGFloat = 32) -> FavoriteFolderTabLayout {
        let width = availableWidth.isFinite ? max(0, availableWidth) : 0
        var knownIds = Set<Int32>()
        let tabs = tabs.filter { knownIds.insert($0.id).inserted }
        let favorites = Set(favoriteTabIds ?? Array(tabs.prefix(4)).map { $0.id })
        var visible = tabs.filter { favorites.contains($0.id) }
        let menuWidth = tabs.isEmpty ? 0 : min(width, overflowWidth.isFinite ? max(0, overflowWidth) : 0)

        while !visible.isEmpty {
            let slotWidth = (width - menuWidth) / CGFloat(visible.count)
            if let index = visible.lastIndex(where: { !$0.minimumWidth.isFinite || max(0, $0.minimumWidth) > slotWidth }) {
                visible.remove(at: index)
            } else {
                break
            }
        }

        let visibleIds = visible.map { $0.id }
        let visibleSet = Set(visibleIds)
        return FavoriteFolderTabLayout(visibleIds: visibleIds, overflowIds: tabs.filter { !visibleSet.contains($0.id) }.map { $0.id }, tabWidth: visible.isEmpty ? 0 : (width - menuWidth) / CGFloat(visible.count), overflowWidth: menuWidth)
    }
}
