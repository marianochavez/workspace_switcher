import XCTest
@testable import WorkspaceSwitcher

final class KeychainServiceTests: XCTestCase {

    // Use a unique service name to avoid conflicts with real data
    private let testService = "WorkspaceSwitcherTests-\(UUID().uuidString)"
    private let testAccount = "test-account"

    override func tearDown() {
        // Clean up any test keychain items
        try? KeychainService.deleteItem(service: testService, account: testAccount)
        try? KeychainService.deleteItem(service: testService, account: "account-2")
        super.tearDown()
    }

    // MARK: - Write and Read

    func testWriteAndReadPassword() throws {
        let testData = Data("secret-password".utf8)
        try KeychainService.writePassword(service: testService, account: testAccount, data: testData)
        let read = try KeychainService.readPassword(service: testService, account: testAccount)
        XCTAssertEqual(read, testData)
    }

    func testWriteUpdatesExisting() throws {
        let data1 = Data("first".utf8)
        let data2 = Data("second".utf8)

        try KeychainService.writePassword(service: testService, account: testAccount, data: data1)
        try KeychainService.writePassword(service: testService, account: testAccount, data: data2)

        let read = try KeychainService.readPassword(service: testService, account: testAccount)
        XCTAssertEqual(read, data2)
    }

    // MARK: - Read non-existent

    func testReadNonExistentThrowsNotFound() {
        XCTAssertThrowsError(try KeychainService.readPassword(
            service: testService, account: "nonexistent"
        )) { error in
            guard let keychainErr = error as? KeychainError,
                  case .itemNotFound = keychainErr else {
                XCTFail("Expected KeychainError.itemNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Delete

    func testDeleteItem() throws {
        let data = Data("to-delete".utf8)
        try KeychainService.writePassword(service: testService, account: testAccount, data: data)
        try KeychainService.deleteItem(service: testService, account: testAccount)
        XCTAssertThrowsError(try KeychainService.readPassword(service: testService, account: testAccount))
    }

    func testDeleteNonExistentDoesNotThrow() {
        XCTAssertNoThrow(try KeychainService.deleteItem(service: testService, account: "nonexistent"))
    }

    // MARK: - List Items

    func testListItemsReturnsWrittenItems() throws {
        try KeychainService.writePassword(
            service: testService, account: testAccount, data: Data("a".utf8)
        )
        try KeychainService.writePassword(
            service: testService, account: "account-2", data: Data("b".utf8)
        )

        let items = KeychainService.listItems(service: testService)
        let accounts = Set(items.map(\.account))
        XCTAssertTrue(accounts.contains(testAccount))
        XCTAssertTrue(accounts.contains("account-2"))
    }

    func testListItemsEmptyForUnknownService() {
        let items = KeychainService.listItems(service: "nonexistent-service-\(UUID())")
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - Binary data

    func testWriteAndReadBinaryData() throws {
        let binaryData = Data([0x00, 0xFF, 0x01, 0xFE, 0x80])
        try KeychainService.writePassword(service: testService, account: testAccount, data: binaryData)
        let read = try KeychainService.readPassword(service: testService, account: testAccount)
        XCTAssertEqual(read, binaryData)
    }

    func testWriteAndReadJSONTokenData() throws {
        let tokenJSON = """
        {"claudeAiOauth":{"accessToken":"sk-test","refreshToken":"rt-test","expiresAt":9999999999,"subscriptionType":"max"}}
        """
        let data = Data(tokenJSON.utf8)
        try KeychainService.writePassword(service: testService, account: testAccount, data: data)
        let read = try KeychainService.readPassword(service: testService, account: testAccount)
        XCTAssertEqual(String(data: read, encoding: .utf8), tokenJSON)
    }
}
