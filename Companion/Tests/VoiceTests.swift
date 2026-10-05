import Carbon.HIToolbox
import XCTest
@testable import Companion

final class SentenceSplitterTests: XCTestCase {
    func testWaitsForSentenceBoundary() {
        var buffer = "Hello there"
        XCTAssertNil(SentenceSplitter.takeCompleteSentences(from: &buffer))
        XCTAssertEqual(buffer, "Hello there")
    }

    func testTakesCompleteSentencesAndKeepsRemainder() {
        var buffer = "Hi! How are you? I'm fi"
        XCTAssertEqual(SentenceSplitter.takeCompleteSentences(from: &buffer), "Hi! How are you?")
        XCTAssertEqual(buffer, " I'm fi")
    }

    func testDoesNotSplitDecimals() {
        var buffer = "It costs 3.50 today"
        XCTAssertNil(SentenceSplitter.takeCompleteSentences(from: &buffer))
    }

    func testNewlineIsABoundary() {
        var buffer = "First line\nsecond"
        XCTAssertEqual(SentenceSplitter.takeCompleteSentences(from: &buffer), "First line\n")
        XCTAssertEqual(buffer, "second")
    }

    func testStripsMarkdown() {
        XCTAssertEqual(SentenceSplitter.stripMarkdown("**Bold** and `code`"), "Bold and code")
    }
}

final class HotKeyComboTests: XCTestCase {
    func testDefaultIsOptionSpace() {
        XCTAssertEqual(HotKeyCombo.defaultPushToTalk.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(HotKeyCombo.defaultPushToTalk.carbonModifiers, UInt32(optionKey))
        XCTAssertEqual(HotKeyCombo.defaultPushToTalk.displayString, "⌥Space")
    }

    func testConvertsCocoaModifiers() {
        let combo = HotKeyCombo(keyCode: UInt16(kVK_Space), modifierFlags: [.command, .shift])
        XCTAssertEqual(combo.carbonModifiers, UInt32(cmdKey) | UInt32(shiftKey))
        XCTAssertEqual(combo.displayString, "⇧⌘Space")
    }

    func testRoundTripsThroughJSON() throws {
        let combo = HotKeyCombo(keyCode: 49, carbonModifiers: UInt32(controlKey))
        let decoded = try JSONDecoder().decode(HotKeyCombo.self, from: JSONEncoder().encode(combo))
        XCTAssertEqual(decoded, combo)
    }
}

@MainActor
final class VoiceSettingsTests: XCTestCase {
    func testShouldSpeak() {
        let defaults = UserDefaults(suiteName: "VoiceSettingsTests-\(UUID())")!
        let settings = VoiceSettings(defaults: defaults)
        XCTAssertTrue(settings.shouldSpeak(.voice))
        XCTAssertFalse(settings.shouldSpeak(.typed))
        settings.speakTypedReplies = true
        XCTAssertTrue(settings.shouldSpeak(.typed))
        settings.isMuted = true
        XCTAssertFalse(settings.shouldSpeak(.voice))
        XCTAssertTrue(VoiceSettings(defaults: defaults).isMuted, "persists")
    }
}

@MainActor
final class CompanionBrainStateTests: XCTestCase {
    func testStatePriority() {
        let brain = CompanionBrain(personality: "", apiKeyProvider: { nil })
        XCTAssertEqual(brain.state, .idle)
        brain.isSpeaking = true
        XCTAssertEqual(brain.state, .talking)
        brain.isListening = true
        XCTAssertEqual(brain.state, .listening)
    }

    func testSendWithoutKeyReportsError() {
        let brain = CompanionBrain(personality: "", apiKeyProvider: { nil })
        brain.send("hi")
        XCTAssertNotNil(brain.lastError)
        XCTAssertTrue(brain.messages.isEmpty)
        XCTAssertFalse(brain.isBusy)
    }
}
