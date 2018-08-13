import XCTest
import PusherPlatform
@testable import PusherChatkit

class CursorTests: XCTestCase {
    var aliceChatManager: ChatManager!
    var bobChatManager: ChatManager!
    var alice: PCCurrentUser!
    var bob: PCCurrentUser!
    var roomID: Int!

    override func setUp() {
        super.setUp()

        aliceChatManager = newTestChatManager(userID: "alice")
        bobChatManager = newTestChatManager(userID: "bob")

        let deleteResourcesEx = expectation(description: "delete resources")
        let createRolesEx = expectation(description: "create roles")
        let createAliceEx = expectation(description: "create Alice")
        let createBobEx = expectation(description: "create Bob")
        let connectAliceEx = expectation(description: "connect as Alice")
        let connectBobEx = expectation(description: "connect as Bob")
        let createRoomEx = expectation(description: "create room")

        deleteInstanceResources() { err in
            XCTAssertNil(err)
            deleteResourcesEx.fulfill()

            createStandardInstanceRoles() { err in
                XCTAssertNil(err)
                createRolesEx.fulfill()
            }

            createUser(id: "alice") { err in
                XCTAssertNil(err)
                createAliceEx.fulfill()
            }

            createUser(id: "bob") { err in
                XCTAssertNil(err)
                createBobEx.fulfill()
            }

            // TODO the following should really wait until we know both Alice
            // and Bob exist... for now, sleep!
            sleep(1)

            self.aliceChatManager.connect(delegate: TestingChatManagerDelegate()) { a, err in
                XCTAssertNil(err)
                self.alice = a
                connectAliceEx.fulfill()

                self.alice.createRoom(name: "mushroom", addUserIDs: ["bob"]) { room, err in
                    XCTAssertNil(err)
                    self.roomID = room!.id
                    createRoomEx.fulfill()

                    self.bobChatManager.connect(delegate: TestingChatManagerDelegate()) { b, err in
                        XCTAssertNil(err)
                        self.bob = b
                        connectBobEx.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: 15)
    }

    override func tearDown() {
        aliceChatManager.disconnect()
        aliceChatManager = nil
        alice = nil
        bobChatManager.disconnect()
        bobChatManager = nil
        bob = nil
        roomID = nil
    }

    func testOwnReadCursorUndefinedIfNotSet() {
        let cursor = try! alice.readCursor(roomID: roomID)
        XCTAssertNil(cursor)
    }

    // TODO hook for setting own read cursor? (currently unsupported by the looks of it)

    func testGetOwnReadCursor() {
        let ex = expectation(description: "got own read cursor")

        alice.setReadCursor(position: 42, roomID: roomID) { error in
            XCTAssertNil(error)

            sleep(1) // give the read cursor a chance to propagate down the connection
            let cursor = try! self.alice.readCursor(roomID: self.roomID)
            XCTAssertEqual(cursor?.position, 42)

            ex.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testNewReadCursorHook() {
        let ex = expectation(description: "received new read cursor")

        let newCursor = { (cursor: PCCursor) -> Void in
            XCTAssertEqual(cursor.position, 42)
            ex.fulfill()
        }

        let aliceDelegate = TestingChatManagerDelegate(newCursor: newCursor)
        self.alice.delegate = aliceDelegate

        self.bob.setReadCursor(position: 42, roomID: self.roomID) { error in
            XCTAssertNil(error)
        }

        waitForExpectations(timeout: 15)
    }

    func testGetAnotherUsersReadCursor() {
        let ex = expectation(description: "got another users read cursor")

        self.bob.setReadCursor(position: 42, roomID: self.roomID) { error in
            XCTAssertNil(error)

            sleep(1) // give the read cursor a chance to propagate down the connection
            let cursor = try! self.alice.readCursor(roomID: self.roomID, userID: "bob")
            XCTAssertEqual(cursor?.position, 42)

            ex.fulfill()
        }

        waitForExpectations(timeout: 15)
    }
}
