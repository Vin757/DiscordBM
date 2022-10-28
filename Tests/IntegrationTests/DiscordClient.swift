import DiscordBM
import AsyncHTTPClient
import XCTest

class DiscordClientTests: XCTestCase {
    
    func testMessageSendDelete() async throws {
        
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            try! httpClient.syncShutdown()
        }
        
        let client = DefaultDiscordClient(
            httpClient: httpClient,
            token: Constants.token,
            appId: Constants.appId
        )
        
        let text = "Testing! \(Date())"
        let createResponse = try await client.createMessage(
            channelId: Constants.testChannel,
            payload: .init(content: text)
        )
        
        XCTAssertEqual(createResponse.httpResponse.status, .ok)
        let message = try createResponse.decode()
        XCTAssertEqual(message.content, text)
        
        let deletionResponse = try await client.deleteMessage(
            channelId: Constants.testChannel,
            messageId: message.id
        )
        
        XCTAssertEqual(deletionResponse.status, .noContent)
    }
}