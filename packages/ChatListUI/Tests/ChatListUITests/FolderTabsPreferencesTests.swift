import XCTest
import InAppSettings
@testable import ChatListUI

final class FolderTabsPreferencesTests: XCTestCase {
    func testLegacyPreferencesKeepScrollableTabs() throws {
        let settings = try JSONDecoder().decode(ChatListFoldersSettings.self, from: Data("{\"t\":0,\"i\":1}".utf8))
        XCTAssertFalse(settings.compactTabs)
        XCTAssertNil(settings.favoriteTabIds)
        XCTAssertTrue(settings.interacted)
    }

    func testFavoriteSelectionRoundTripsIncludingAnEmptySelection() throws {
        for ids: [Int32]? in [nil, [], [-1, 2, 5]] {
            let settings = ChatListFoldersSettings(sidebar: false, interacted: true, compactTabs: true, favoriteTabIds: ids)
            let decoded = try JSONDecoder().decode(ChatListFoldersSettings.self, from: JSONEncoder().encode(settings))
            XCTAssertTrue(decoded.compactTabs)
            XCTAssertEqual(decoded.favoriteTabIds, ids)
        }
    }

    func testExistingSettingsUpdatesPreserveFavoriteTabs() {
        let settings = ChatListFoldersSettings(sidebar: false, interacted: false, compactTabs: true, favoriteTabIds: [-1, 2, 5])
        let updated = settings.withUpdatedSidebar(true).withUpdatedSidebarInteracted(true)
        XCTAssertTrue(updated.sidebar)
        XCTAssertTrue(updated.interacted)
        XCTAssertTrue(updated.compactTabs)
        XCTAssertEqual(updated.favoriteTabIds, [-1, 2, 5])
        XCTAssertEqual(updated.withUpdatedCompactTabs(false).favoriteTabIds, [-1, 2, 5])
    }

    func testChatListStateUpdatesPreserveFavoriteTabs() {
        let state = FilterData(compactTabs: true, favoriteTabIds: [-1, 2, 5])
        let updates = [
            state.withUpdatedFilterId(nil),
            state.withUpdatedFilter(nil),
            state.withUpdatedTabs([]),
            state.withUpdatedSidebar(true),
            state.withUpdatedShowTags(true),
            state.withUpdatedRequest(.Initial(100, nil), removeAnimation: false),
            state.withUpdatedIsTop(false),
            state.withUpdatedBadges(.init(total: 0, filters: []))
        ]
        for updated in updates {
            XCTAssertTrue(updated.compactTabs)
            XCTAssertEqual(updated.favoriteTabIds, [-1, 2, 5])
        }
    }
}
