import AcornAgent

func toolNames(in messages: [ChatMessage]) -> [String] {
    messages.flatMap(\.content).compactMap(\.asToolUse).map(\.name)
}

func lastAssistantReply(in messages: [ChatMessage]) -> String {
    messages
        .last(where: { $0.role == .assistant })
        .map { $0.content.compactMap(\.asText).joined() } ?? ""
}
