import XCTest
@testable import ChatListUI

final class FavoriteFolderTabLayoutTests: XCTestCase {
    private let tabs = (1...6).map { FavoriteFolderTabLayout.Tab(id: Int32($0), minimumWidth: 60) }

    func testDefaultFavoritesShareAvailableWidthEqually() {
        let layout = FavoriteFolderTabLayout.make(tabs: tabs, favoriteTabIds: nil, availableWidth: 352)
        XCTAssertEqual(layout.visibleIds, [1, 2, 3, 4])
        XCTAssertEqual(layout.overflowIds, [5, 6])
        XCTAssertEqual(layout.tabWidth, 80)
        XCTAssertEqual(layout.overflowWidth, 32)
    }

    func testNarrowWidthMovesFavoritesToOverflowWithoutLosingFolders() {
        let layout = FavoriteFolderTabLayout.make(tabs: tabs, favoriteTabIds: nil, availableWidth: 160)
        XCTAssertEqual(layout.visibleIds, [1, 2])
        XCTAssertEqual(layout.overflowIds, [3, 4, 5, 6])
        XCTAssertEqual(layout.tabWidth, 64)
    }

    func testLongTitleMovesToOverflowWhileOtherFavoritesRemainVisible() {
        let tabs = [FavoriteFolderTabLayout.Tab(id: 1, minimumWidth: 300), .init(id: 2, minimumWidth: 50), .init(id: 3, minimumWidth: 50)]
        let layout = FavoriteFolderTabLayout.make(tabs: tabs, favoriteTabIds: nil, availableWidth: 200)
        XCTAssertEqual(layout.visibleIds, [2, 3])
        XCTAssertEqual(layout.overflowIds, [1])
        XCTAssertEqual(layout.tabWidth, 84)
    }

    func testExplicitFavoritesKeepFolderOrderAndIgnoreStaleIds() {
        let layout = FavoriteFolderTabLayout.make(tabs: tabs, favoriteTabIds: [4, 2, 4, 99], availableWidth: 352)
        XCTAssertEqual(layout.visibleIds, [2, 4])
        XCTAssertEqual(layout.overflowIds, [1, 3, 5, 6])
    }

    func testNoFavoritesLeavesAllFoldersInMenu() {
        let layout = FavoriteFolderTabLayout.make(tabs: tabs, favoriteTabIds: [], availableWidth: 352)
        XCTAssertEqual(layout.visibleIds, [])
        XCTAssertEqual(layout.overflowIds, [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(layout.tabWidth, 0)
    }

    func testMenuRemainsAvailableWhenEveryFolderIsFavorite() {
        let layout = FavoriteFolderTabLayout.make(tabs: Array(tabs.prefix(2)), favoriteTabIds: [1, 2], availableWidth: 352)
        XCTAssertEqual(layout.visibleIds, [1, 2])
        XCTAssertEqual(layout.overflowIds, [])
        XCTAssertEqual(layout.overflowWidth, 32)
    }

    func testVeryNarrowAndEmptyLayoutsStayWithinBounds() {
        let layout = FavoriteFolderTabLayout.make(tabs: tabs, favoriteTabIds: nil, availableWidth: 20)
        XCTAssertEqual(layout.visibleIds, [])
        XCTAssertEqual(layout.overflowWidth, 20)
        let empty = FavoriteFolderTabLayout.make(tabs: [], favoriteTabIds: nil, availableWidth: 352)
        XCTAssertEqual(empty.tabWidth, 0)
        XCTAssertEqual(empty.overflowWidth, 0)
    }

    func testDuplicateIdsAreRenderedOnlyOnce() {
        let layout = FavoriteFolderTabLayout.make(tabs: tabs + [tabs[0]], favoriteTabIds: nil, availableWidth: 352)
        XCTAssertEqual(layout.visibleIds + layout.overflowIds, [1, 2, 3, 4, 5, 6])
    }
}
