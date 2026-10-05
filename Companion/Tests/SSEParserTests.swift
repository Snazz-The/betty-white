import XCTest
@testable import Companion

final class SSEParserTests: XCTestCase {
    func testTextDelta() {
        let line = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi there"}}"#
        XCTAssertEqual(SSEParser.parse(line: line), .textDelta("Hi there"))
    }

    func testMessageStop() {
        XCTAssertEqual(SSEParser.parse(line: #"data: {"type":"message_stop"}"#), .stop)
    }

    func testErrorEvent() {
        let line = #"data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
        XCTAssertEqual(SSEParser.parse(line: line), .error("Overloaded"))
    }

    func testIgnoresOtherLines() {
        XCTAssertNil(SSEParser.parse(line: "event: content_block_delta"))
        XCTAssertNil(SSEParser.parse(line: #"data: {"type":"ping"}"#))
        XCTAssertNil(SSEParser.parse(line: #"data: {"type":"message_start","message":{}}"#))
        XCTAssertNil(SSEParser.parse(line: #"data: {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{"}}"#))
        XCTAssertNil(SSEParser.parse(line: "data: not json"))
    }
}

final class AnthropicClientTests: XCTestCase {
    func testRequestShape() throws {
        let client = AnthropicClient(apiKey: "test-key")
        let request = try client.makeRequest(
            system: "Be nice.",
            messages: [.init(role: "user", content: "Hello")],
            maxTokens: 42
        )
        XCTAssertEqual(request.url, Config.apiURL)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), Config.apiVersion)

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, Config.model)
        XCTAssertEqual(json["max_tokens"] as? Int, 42)
        XCTAssertEqual(json["system"] as? String, "Be nice.")
        XCTAssertEqual(json["stream"] as? Bool, true)
    }

    func testErrorMessageFromBody() {
        let body = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        XCTAssertEqual(AnthropicError.message(fromBody: body), "invalid x-api-key")
        XCTAssertEqual(AnthropicError.message(fromBody: "oops"), "oops")
    }
}

final class PersonalityTests: XCTestCase {
    func testVoiceOriginAddsAddendum() {
        XCTAssertEqual(Personality.systemPrompt(base: "Base", origin: .typed), "Base")
        XCTAssertTrue(Personality.systemPrompt(base: "Base", origin: .voice).hasPrefix("Base"))
        XCTAssertTrue(Personality.systemPrompt(base: "Base", origin: .voice).count > "Base".count)
    }

    func testBundledPersonalityLoads() {
        XCTAssertNotEqual(Personality.load(), Personality.fallback, "Personality.md should be bundled")
    }
}
