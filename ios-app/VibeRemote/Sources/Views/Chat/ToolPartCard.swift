import SwiftUI

struct ToolPartCard: View {
    let tool: ToolPart
    @State private var isExpanded = false
    
    private var iconColor: Color {
        switch tool.tool {
        case "read": return Color(hex: "5AC8FA")
        case "write", "edit": return Color(hex: "FF9500")
        case "bash": return Color(hex: "34C759")
        case "glob", "grep": return Color(hex: "AF52DE")
        default:
            if tool.tool.hasPrefix("lsp_") { return Color(hex: "007AFF") }
            return VibeTheme.Colors.fgSecondary
        }
    }
    
    private var statusString: String? {
        tool.state?.status
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
                Image(systemName: tool.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                Text(tool.displayName)
                    .font(VibeTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(VibeTheme.Colors.fg)
                
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
        switch statusString {
        case "running", "pending":
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        case "completed", "success":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(VibeTheme.Colors.Fallback.success)
        case "error", "failed":
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
            
            if let input = tool.state?.input {
                inputSection(input)
            }
            
            if let output = tool.state?.output {
                outputSection(output)
            }
        }
        .padding(VibeTheme.Spacing.sm)
        .background(VibeTheme.Colors.code)
    }
    
    private func inputSection(_ input: AnyCodableValue) -> some View {
        VStack(alignment: .leading, spacing: VibeTheme.Spacing.xs) {
            Text("Input")
                .font(VibeTheme.Typography.codeSmall)
                .foregroundStyle(VibeTheme.Colors.fgTertiary)
            
            if let dict = input.value as? [String: Any] {
                ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                    HStack(alignment: .top, spacing: VibeTheme.Spacing.xs) {
                        Text(key)
                            .font(VibeTheme.Typography.codeSmall)
                            .foregroundStyle(VibeTheme.Colors.fgTertiary)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text(stringValue(for: dict[key]))
                            .font(VibeTheme.Typography.codeSmall)
                            .foregroundStyle(VibeTheme.Colors.fg)
                            .textSelection(.enabled)
                            .lineLimit(5)
                    }
                }
            } else {
                Text(stringValue(for: input.value))
                    .font(VibeTheme.Typography.codeSmall)
                    .foregroundStyle(VibeTheme.Colors.fg)
                    .textSelection(.enabled)
            }
        }
    }
    
    private func outputSection(_ output: AnyCodableValue) -> some View {
        VStack(alignment: .leading, spacing: VibeTheme.Spacing.xs) {
            Text("Output")
                .font(VibeTheme.Typography.codeSmall)
                .foregroundStyle(VibeTheme.Colors.fgTertiary)
            
            Text(stringValue(for: output.value))
                .font(VibeTheme.Typography.codeSmall)
                .foregroundStyle(VibeTheme.Colors.fg)
                .textSelection(.enabled)
                .lineLimit(10)
        }
    }
    
    private func stringValue(for value: Any?) -> String {
        guard let value = value else { return "" }
        if let str = value as? String { return str }
        if let int = value as? Int { return String(int) }
        if let bool = value as? Bool { return String(bool) }
        if let double = value as? Double { return String(format: "%.2f", double) }
        return String(describing: value)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToolPartCard(tool: ToolPart(
            type: "tool",
            callID: "1",
            tool: "glob",
            state: ToolState(
                status: "completed",
                input: AnyCodableValue(["pattern": "**/*.swift"]),
                output: AnyCodableValue("Found 15 files"),
                metadata: nil
            )
        ))
        
        ToolPartCard(tool: ToolPart(
            type: "tool",
            callID: "2",
            tool: "bash",
            state: ToolState(
                status: "running",
                input: AnyCodableValue(["command": "npm test"]),
                output: nil,
                metadata: nil
            )
        ))
    }
    .padding()
    .background(VibeTheme.Colors.bg)
    .preferredColorScheme(.dark)
}
