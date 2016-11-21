import Foundation
import XCTest
import OHHTTPStubs
@testable import WordPress


// MARK: - NotificationSyncServiceTests
//
class NotificationSyncServiceTests: XCTestCase
{
    /// CoreData Context Manager
    ///
    private var manager: TestContextManager!

    /// WordPress REST API
    ///
    private var dotcomAPI: WordPressComRestApi!

    /// Sync Service
    ///
    private var service: NotificationSyncService!

    /// Expectation's Timeout
    ///
    private let timeout = NSTimeInterval(3)


    // MARK: - Overriden Methods

    override func setUp() {
        super.setUp()

        manager = TestContextManager()
        dotcomAPI = WordPressComRestApi(oAuthToken: "1234", userAgent: "yosemite")
        service = NotificationSyncService(manager: manager, dotcomAPI: dotcomAPI)

        // Note:
        // Since the TestContextManager actually changed, and thus, the entire Core Data stack,
        // we'll need to manually reset the global shared Derived Context.
        // This definitely won't be needed in the actual app.
        //
        NotificationSyncService.resetSharedDerivedContext()
    }

    override func tearDown() {
        super.tearDown()

        OHHTTPStubs.removeAllStubs()
    }


    /// Verifies that NotificationsSyncService effectively inserts a single Notification when *sync* is called.
    /// Normally it'd insert 100, but... that's how our Testing Data looks like!
    ///
    func testSyncEffectivelyInsertsASingleNotification() {
        // Stub Endpoint
        let endpoint = "notifications/"
        let stubPath = OHPathForFile("notifications-load-all.json", self.dynamicType)!
        OHHTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubPath)

        // Make sure the collection is empty, to begin with
        let helper = CoreDataHelper<Notification>(context: self.manager.mainContext)
        XCTAssert(helper.countObjects() == 0)

        // CoreData Expectations
        manager.testExpectation = expectationWithDescription("Context save expectation")

        // Service Expectations
        let expectation = expectationWithDescription("Sync")

        // Sync!
        service.sync { _ in
            XCTAssert(helper.countObjects() == 1)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }


    /// Verifies that the Sync call, when called repeatedly, won't duplicate our local dataset.
    ///
    func testMultipleSyncCallsWontInsertDuplicateNotes() {
        // Stub Endpoint
        let endpoint = "notifications/"
        let stubPath = OHPathForFile("notifications-load-all.json", self.dynamicType)!
        OHHTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubPath)

        // Make sure the collection is empty, to begin with
        let helper = CoreDataHelper<Notification>(context: manager.mainContext)
        XCTAssert(helper.countObjects() == 0)

        // Shutdown Expectation Warnings. Please
        manager.requiresTestExpectation = false

        // Wait until all the workers complete
        let group = dispatch_group_create()

        // CoreData Expectations
        for _ in 0..<100 {
            dispatch_group_enter(group)

            let newService = NotificationSyncService(manager: manager, dotcomAPI: dotcomAPI)
            newService?.sync { _ in
                dispatch_group_leave(group)
            }
        }

        // Verify there's no duplication
        let expectation = expectationWithDescription("Async!")

        dispatch_group_notify(group, dispatch_get_main_queue()) {
            XCTAssert(helper.countObjects() == 1)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }


    /// Verifies that RefreshNotification withID effectively loads a single Notification from the remote endpoint.
    ///
    func testSyncNoteEffectivelyReturnsASingleNotification() {
        // Stub Endpoint
        let endpoint = "notifications/"
        let stubPath = OHPathForFile("notifications-load-all.json", self.dynamicType)!
        OHHTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubPath)

        // Make sure the collection is empty, to begin with
        let helper = CoreDataHelper<Notification>(context: self.manager.mainContext)
        XCTAssert(helper.countObjects() == 0)

        // CoreData Expectations
        manager.testExpectation = expectationWithDescription("Context save expectation")

        // Service Expectations
        let expectation = expectationWithDescription("Sync")

        // Sync!
        service.syncNote(with: "2674124016") { error, note in
            XCTAssertNil(error)
            XCTAssertNotNil(note)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }


    /// Verifies that Mark as Read effectively toggles a Notification's read flag
    ///
    func testMarkAsReadEffectivelyTogglesNotificationReadStatus() {
        // Stub Endpoint
        let endpoint = "notifications/read"
        let stubPath = OHPathForFile("notifications-mark-as-read.json", self.dynamicType)!
        OHHTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubPath)

        // Inject Dummy Note
        let path = "notifications-like.json"
        let note = manager.loadEntityNamed(Notification.entityName, withContentsOfFile: path) as! Notification

        XCTAssertNotNil(note)
        XCTAssertFalse(note.read)

        // CoreData Expectations
        manager.testExpectation = expectationWithDescription("Context save expectation")

        // Service Expectations
        let expectation = expectationWithDescription("Mark as Read")

        // Mark as Read!
        service.markAsRead(note) { success in
            XCTAssertTrue(note.read)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }


    /// Verifies that updateLastSeen method effectively calls the callback with successfull flag
    ///
    func testUpdateLastSeenHitsCallbackWithSuccessfulResult() {
        // Stub Endpoint
        let endpoint = "notifications/seen"
        let stubPath = OHPathForFile("notifications-last-seen.json", self.dynamicType)!
        OHHTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubPath)

        // Service Expectations
        let expectation = expectationWithDescription("Update Last Seen")

        // Update Last Seen!
        service.updateLastSeen("1234") { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }
}
