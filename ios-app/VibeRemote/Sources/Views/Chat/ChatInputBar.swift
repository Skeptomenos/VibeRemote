import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let commands: [SlashCommand]
    let onSend: () async -> Void
    let onStop: () async -> Void
    
    @State private var showCommands = false
    @FocusState private var isFocused: Bool
    
    private var filteredCommands: [SlashCommand] {
        guard text.hasPrefix("/") else { return [] }
        let query = String(text.dropFirst()).lowercased()
        if query.isEmpty { return commands }
        return commands.filter { $0.name.lowercased().contains(query) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showCommands && !filteredCommands.isEmpty {
                commandSuggestions
            }
            
            inputBar
        }
    }
    
    private var commandSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VibeTheme.Spacing.xs) {
                ForEach(filteredCommands) { command in
                    Button(action: {
                        text = "/\(command.name) "
                        showCommands = false
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("/\(command.name)")
                                .font(VibeTheme.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(VibeTheme.Colors.fg)
                            
                            Text(command.description)
                                .font(VibeTheme.Typography.caption2)
                                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, VibeTheme.Spacing.sm)
                        .padding(.vertical, VibeTheme.Spacing.xs)
                        .background(VibeTheme.Colors.surfaceSecondary)
                        .cornerRadius(VibeTheme.Radius.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VibeTheme.Spacing.md)
            .padding(.vertical, VibeTheme.Spacing.xs)
        }
        .background(VibeTheme.Colors.surfacePrimary)
    }
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: VibeTheme.Spacing.sm) {
            TextField("Message...", text: $text, axis: .vertical)
                .font(VibeTheme.Typography.body)
                .foregroundStyle(VibeTheme.Colors.fg)
                .lineLimit(1...5)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    showCommands = newValue.hasPrefix("/")
                }
                .padding(.horizontal, VibeTheme.Spacing.md)
                .padding(.vertical, VibeTheme.Spacing.sm)
            
            actionButton
                .padding(.trailing, VibeTheme.Spacing.xs)
                .padding(.bottom, VibeTheme.Spacing.xs)
        }
        .background(VibeTheme.Colors.surfacePrimary)
        .cornerRadius(VibeTheme.Radius.pill)
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.Radius.pill)
                .stroke(
                    isFocused ? VibeTheme.Colors.tint : VibeTheme.Colors.codeLine,
                    lineWidth: 1
                )
        )
        .vibeShadow(isFocused ? VibeTheme.Shadow.inputGlow : VibeTheme.Shadow.subtle)
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if isStreaming {
            Button(action: { Task { await onStop() } }) {
                Image(systemName: VibeTheme.Icons.stop)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(VibeTheme.Colors.Fallback.error)
                    .clipShape(Circle())
            }
        } else {
            Button(action: { Task { await onSend() } }) {
                Image(systemName: VibeTheme.Icons.send)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? VibeTheme.Colors.fgTertiary
                        : VibeTheme.Colors.tint)
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputBar(
            text: .constant(""),
            isStreaming: false,
            commands: [
                SlashCommand(name: "clear", description: "Clear the conversation"),
                SlashCommand(name: "compact", description: "Compact the context"),
                SlashCommand(name: "undo", description: "Undo last change")
            ],
            onSend: {},
            onStop: {}
        )
        .padding()
    }
    .background(VibeTheme.Colors.bg)
    .preferredColorScheme(.dark)
}
