import SwiftUI

struct ToolCallCard: View {
    let tool: ToolInvocationPart
    @State private var isExpanded = false
    
    private var invocation: ToolInvocation {
        tool.toolInvocation
    }
    
    private var iconColor: Color {
        switch invocation.toolName {
        case "read": return Color(hex: "5AC8FA")
        case "write", "edit": return Color(hex: "FF9500")
        case "bash": return Color(hex: "34C759")
        case "glob", "grep": return Color(hex: "AF52DE")
        default: return VibeTheme.Colors.fgSecondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedHeader
            
            if isExpanded {
                expandedContent
            }
        }
        .background(VibeTheme.Colors.surfacePrimary)
        .cornerRadius(VibeTheme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.Radius.sm)
                .stroke(VibeTheme.Colors.codeLine, lineWidth: 1)
        )
    }
    
    private var collapsedHeader: some View {
        Button(action: { withAnimation(VibeTheme.Animation.quick) { isExpanded.toggle() } }) {
            HStack(spacing: VibeTheme.Spacing.xs) {
                Image(systemName: invocation.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                Text(invocation.displayName)
                    .font(VibeTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(VibeTheme.Colors.fg)
                
                if let path = invocation.filePath {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(VibeTheme.Typography.caption)
                        .foregroundStyle(VibeTheme.Colors.fgSecondary)
                        .lineLimit(1)
                }
                
                if let command = invocation.command {
                    Text(command)
                        .font(VibeTheme.Typography.codeSmall)
                        .foregroundStyle(VibeTheme.Colors.fgSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                stateIndicator
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VibeTheme.Colors.fgTertiary)
            }
            .padding(VibeTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var stateIndicator: some View {
        switch invocation.state {
        case "running":
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        case "result":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(VibeTheme.Colors.Fallback.success)
        case "error":
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(VibeTheme.Colors.Fallback.error)
        default:
            EmptyView()
        }
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: VibeTheme.Spacing.xs) {
            Divider()
                .background(VibeTheme.Colors.codeLine)
            
            ForEach(Array(invocation.args.keys.sorted()), id: \.self) { key in
                HStack(alignment: .top, spacing: VibeTheme.Spacing.xs) {
                    Text(key)
                        .font(VibeTheme.Typography.codeSmall)
                        .foregroundStyle(VibeTheme.Colors.fgTertiary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(stringValue(for: invocation.args[key]))
                        .font(VibeTheme.Typography.codeSmall)
                        .foregroundStyle(VibeTheme.Colors.fg)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(VibeTheme.Spacing.sm)
        .background(VibeTheme.Colors.code)
    }
    
    private func stringValue(for value: AnyCodableValue?) -> String {
        guard let value = value else { return "" }
        if let str = value.stringValue { return str }
        if let int = value.intValue { return String(int) }
        if let bool = value.boolValue { return String(bool) }
        return String(describing: value.value)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToolCallCard(tool: ToolInvocationPart(
            type: "tool-invocation",
            toolInvocation: ToolInvocation(
                toolName: "read",
                toolCallId: "1",
                args: ["filePath": AnyCodableValue("/src/auth.ts")],
                state: "result"
            )
        ))
        
        ToolCallCard(tool: ToolInvocationPart(
            type: "tool-invocation",
            toolInvocation: ToolInvocation(
                toolName: "bash",
                toolCallId: "2",
                args: ["command": AnyCodableValue("npm test")],
                state: "running"
            )
        ))
        
        ToolCallCard(tool: ToolInvocationPart(
            type: "tool-invocation",
            toolInvocation: ToolInvocation(
                toolName: "edit",
                toolCallId: "3",
                args: [
                    "filePath": AnyCodableValue("/src/auth.ts"),
                    "oldString": AnyCodableValue("const x = 1"),
                    "newString": AnyCodableValue("const x = 2")
                ],
                state: "result"
            )
        ))
    }
    .padding()
    .background(VibeTheme.Colors.bg)
    .preferredColorScheme(.dark)
}
