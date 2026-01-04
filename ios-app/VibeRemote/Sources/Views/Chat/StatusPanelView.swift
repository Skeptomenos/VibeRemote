import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var totalTokens: Int {
        viewModel.messages.compactMap { $0.info.tokens }.reduce(0) { $0 + $1.total }
    }
    
    private var totalCost: Double {
        viewModel.messages.compactMap { $0.info.cost }.reduce(0, +)
    }
    
    var body: some View {
        NavigationStack {
            List {
                sessionStatsSection
                modifiedFilesSection
                todoSection
                mcpSection
                lspSection
                actionsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Session Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await viewModel.refreshStatus() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshStatus()
            }
            .task {
                await viewModel.refreshStatus()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var sessionStatsSection: some View {
        Section("Session Statistics") {
            StatRow(icon: "message", label: "Messages", value: "\(viewModel.messages.count)")
            StatRow(icon: "number", label: "Total Tokens", value: formatNumber(totalTokens))
            StatRow(icon: "dollarsign.circle", label: "Estimated Cost", value: String(format: "$%.4f", totalCost))
            
            if let stats = viewModel.sessionStats {
                StatRow(icon: "clock", label: "Execution Time", value: String(format: "%.1fs", stats.executionTime))
            }
        }
    }
    
    @ViewBuilder
    private var modifiedFilesSection: some View {
        if !viewModel.diffs.isEmpty {
            Section("Modified Files (\(viewModel.diffs.count))") {
                ForEach(viewModel.diffs) { diff in
                    NavigationLink {
                        DiffDetailView(diff: diff)
                    } label: {
                        HStack(spacing: VibeTheme.Spacing.xs) {
                            Image(systemName: "doc.badge.ellipsis")
                                .foregroundStyle(VibeTheme.Colors.Fallback.warning)
                            
                            Text(diff.fileName)
                                .font(VibeTheme.Typography.body)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var todoSection: some View {
        if !viewModel.todos.isEmpty {
            Section("Todo List") {
                ForEach(viewModel.todos) { todo in
                    HStack(spacing: VibeTheme.Spacing.xs) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isCompleted ? VibeTheme.Colors.Fallback.success : VibeTheme.Colors.fgTertiary)
                        
                        Text(todo.content)
                            .font(VibeTheme.Typography.body)
                            .strikethrough(todo.isCompleted)
                            .foregroundStyle(todo.isCompleted ? VibeTheme.Colors.fgSecondary : VibeTheme.Colors.fg)
                        
                        Spacer()
                        
                        priorityBadge(todo.priority)
                    }
                }
            }
        }
    }
    
    private var mcpSection: some View {
        Section("MCP Servers") {
            if viewModel.mcpStatus.isEmpty {
                Text("No MCP servers configured")
                    .font(VibeTheme.Typography.body)
                    .foregroundStyle(VibeTheme.Colors.fgSecondary)
            } else {
                ForEach(Array(viewModel.mcpStatus.values)) { server in
                    HStack(spacing: VibeTheme.Spacing.xs) {
                        Circle()
                            .fill(server.isConnected ? VibeTheme.Colors.Fallback.success : VibeTheme.Colors.Fallback.error)
                            .frame(width: 8, height: 8)
                        
                        Text(server.name)
                            .font(VibeTheme.Typography.body)
                        
                        Spacer()
                        
                        if !server.isConnected {
                            Button("Connect") {
                                Task { await viewModel.connectMCP(name: server.name) }
                            }
                            .font(VibeTheme.Typography.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else if let tools = server.tools {
                            Text("\(tools.count) tools")
                                .font(VibeTheme.Typography.caption)
                                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                        }
                    }
                }
            }
        }
    }
    
    private var lspSection: some View {
        Section("Language Servers") {
            if viewModel.lspStatus.isEmpty {
                Text("No language servers active")
                    .font(VibeTheme.Typography.body)
                    .foregroundStyle(VibeTheme.Colors.fgSecondary)
            } else {
                ForEach(viewModel.lspStatus) { lsp in
                    HStack(spacing: VibeTheme.Spacing.xs) {
                        Circle()
                            .fill(lsp.isRunning ? VibeTheme.Colors.Fallback.success : VibeTheme.Colors.Fallback.error)
                            .frame(width: 8, height: 8)
                        
                        Text(lsp.name)
                            .font(VibeTheme.Typography.body)
                        
                        Spacer()
                        
                        if let version = lsp.version {
                            Text(version)
                                .font(VibeTheme.Typography.caption)
                                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                        }
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        Section("Actions") {
            Button(role: .destructive) {
                Task { await viewModel.revertChanges() }
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Revert All Changes")
                }
            }
            .disabled(viewModel.diffs.isEmpty)
        }
    }
    
    private func priorityBadge(_ priority: String) -> some View {
        Text(priority.uppercased())
            .font(VibeTheme.Typography.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(priority).opacity(0.2))
            .foregroundStyle(priorityColor(priority))
            .cornerRadius(4)
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return VibeTheme.Colors.Fallback.error
        case "medium": return VibeTheme.Colors.Fallback.warning
        default: return VibeTheme.Colors.fgSecondary
        }
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: VibeTheme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                .frame(width: 20)
            
            Text(label)
                .font(VibeTheme.Typography.body)
            
            Spacer()
            
            Text(value)
                .font(VibeTheme.Typography.body)
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
        }
    }
}

struct DiffDetailView: View {
    let diff: FileDiff
    
    var body: some View {
        ScrollView {
            Text(diff.diff)
                .font(VibeTheme.Typography.code)
                .foregroundStyle(VibeTheme.Colors.fg)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VibeTheme.Colors.code)
        .navigationTitle(diff.fileName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    StatusPanelView(viewModel: ChatViewModel(
        session: AgentSession(name: "Test", projectPath: "/home/linux/TestProject"),
        gatewayURL: URL(string: "https://vibecode.helmes.me")!,
        apiKey: "test"
    ))
    .preferredColorScheme(.dark)
}
