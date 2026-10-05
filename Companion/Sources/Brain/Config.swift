import Foundation

/// App-wide constants. Change the model here and nowhere else.
enum Config {
    static let model = "claude-sonnet-5-5"
    static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

    /// Token budget for replies to typed messages.
    static let typedMaxTokens = 1024
    /// Token budget for replies to spoken messages; these should be short.
    static let voiceMaxTokens = 300
}
