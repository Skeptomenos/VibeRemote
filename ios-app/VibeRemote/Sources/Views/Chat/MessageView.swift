import SwiftUI

struct MessageView: View {
    let message: OpenCodeMessage
    
    private var isUser: Bool {
        message.info.role == .user
    }
    
    private var timestamp: String {
        let date = Date(timeIntervalSince1970: message.info.time.created / 1000)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: VibeTheme.Spacing.xs) {
            if isUser {
                userMessageContent
            } else {
                assistantMessageContent
            }
            
            Text(timestamp)
                .font(VibeTheme.Typography.timestamp)
                .foregroundStyle(VibeTheme.Colors.fgTertiary)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    
    private var userMessageContent: some View {
        Text(message.textContent)
            .font(VibeTheme.Typography.userMessage)
            .foregroundStyle(VibeTheme.Colors.fg)
            .multilineTextAlignment(.trailing)
    }
    
    private var assistantMessageContent: some View {
        VStack(alignment: .leading, spacing: VibeTheme.Spacing.md) {
            ForEach(Array((message.parts ?? []).enumerated()), id: \.offset) { _, part in
                partView(for: part)
            }
        }
    }
    
    @ViewBuilder
    private func partView(for part: MessagePart) -> some View {
        switch part {
        case .text(let textPart):
            Text(textPart.text)
                .font(VibeTheme.Typography.messageBody)
                .foregroundStyle(VibeTheme.Colors.fg)
                .textSelection(.enabled)
            
        case .toolInvocation(let toolPart):
            ToolCallCard(tool: toolPart)
            
        case .tool(let toolPart):
            ToolPartCard(tool: toolPart)
            
        case .toolResult(let resultPart):
            if resultPart.toolResult.isError {
                toolErrorView(resultPart.toolResult.result ?? "Unknown error")
            }
            
        case .file(let filePart):
            fileAttachmentView(filePart)
            
        case .reasoning(let reasoningPart):
            reasoningView(reasoningPart)
            
        case .unknown:
            EmptyView()
        }
    }
    
    private func reasoningView(_ reasoning: ReasoningPart) -> some View {
        VStack(alignment: .leading, spacing: VibeTheme.Spacing.xs) {
            HStack(spacing: VibeTheme.Spacing.xs) {
                Image(systemName: "brain")
                    .font(.system(size: 12))
                    .foregroundStyle(VibeTheme.Colors.fgTertiary)
                Text("Thinking")
                    .font(VibeTheme.Typography.caption)
                    .foregroundStyle(VibeTheme.Colors.fgTertiary)
            }
            
            Text(reasoning.content)
                .font(VibeTheme.Typography.caption)
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                .textSelection(.enabled)
        }
        .padding(VibeTheme.Spacing.sm)
        .background(VibeTheme.Colors.surfacePrimary.opacity(0.5))
        .cornerRadius(VibeTheme.Radius.sm)
    }
    
    private func toolErrorView(_ error: String) -> some View {
        HStack(spacing: VibeTheme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VibeTheme.Colors.Fallback.error)
            
            Text(error)
                .font(VibeTheme.Typography.caption)
                .foregroundStyle(VibeTheme.Colors.Fallback.error)
        }
        .padding(VibeTheme.Spacing.sm)
        .background(VibeTheme.Colors.Fallback.error.opacity(0.1))
        .cornerRadius(VibeTheme.Radius.sm)
    }
    
    private func fileAttachmentView(_ file: FilePart) -> some View {
        HStack(spacing: VibeTheme.Spacing.xs) {
            Image(systemName: "paperclip")
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
            
            Text(URL(fileURLWithPath: file.filePath).lastPathComponent)
                .font(VibeTheme.Typography.caption)
                .foregroundStyle(VibeTheme.Colors.fg)
        }
        .padding(VibeTheme.Spacing.sm)
        .background(VibeTheme.Colors.surfacePrimary)
        .cornerRadius(VibeTheme.Radius.sm)
    }
}

#Preview {
    VStack(spacing: 24) {
        MessageView(message: OpenCodeMessage(
            info: MessageInfo(
                id: "1",
                sessionID: "s1",
                role: .user,
                time: MessageTime(created: Date().timeIntervalSince1970, completed: nil),
                model: nil,
                cost: nil,
                tokens: nil,
                agent: nil,
                parentID: nil,
                modelID: nil,
                providerID: nil,
                mode: nil,
                path: nil,
                error: nil,
                summary: nil
            ),
            parts: [.text(TextPart(type: "text", text: "Can you help me fix this bug?"))]
        ))
        
        MessageView(message: OpenCodeMessage(
            info: MessageInfo(
                id: "2",
                sessionID: "s1",
                role: .assistant,
                time: MessageTime(created: Date().timeIntervalSince1970, completed: Date().timeIntervalSince1970),
                model: MessageModel(providerID: "anthropic", modelID: "claude-sonnet-4-20250514"),
                cost: 0.01,
                tokens: TokenUsage(input: 100, output: 200, reasoning: nil, cache: nil),
                agent: nil,
                parentID: nil,
                modelID: nil,
                providerID: nil,
                mode: nil,
                path: nil,
                error: nil,
                summary: nil
            ),
            parts: [.text(TextPart(type: "text", text: "I'll help you fix that bug. Let me take a look at the code."))]
        ))
    }
    .padding()
    .background(VibeTheme.Colors.bg)
    .preferredColorScheme(.dark)
}
