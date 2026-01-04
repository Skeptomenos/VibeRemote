import SwiftUI

struct ProjectsView: View {
    let gatewayURL: URL
    let apiKey: String
    let onSelectProject: (GatewayProject) -> Void
    
    @State private var projects: [GatewayProject] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var startingProject: String?
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if projects.isEmpty {
                emptyView
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        .task {
            await loadProjects()
        }
        .refreshable {
            await loadProjects()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: VibeTheme.Spacing.md) {
            ProgressView()
            Text("Loading projects...")
                .font(VibeTheme.Typography.body)
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: VibeTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(VibeTheme.Colors.Fallback.warning)
            
            Text("Connection Error")
                .font(VibeTheme.Typography.title3)
                .foregroundStyle(VibeTheme.Colors.fg)
            
            Text(message)
                .font(VibeTheme.Typography.body)
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await loadProjects() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: VibeTheme.Spacing.md) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
            
            Text("No Projects Found")
                .font(VibeTheme.Typography.title3)
                .foregroundStyle(VibeTheme.Colors.fg)
            
            Text("No project directories were found in your home folder.")
                .font(VibeTheme.Typography.body)
                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var projectList: some View {
        List {
            ForEach(projects) { project in
                ProjectRow(
                    project: project,
                    isStarting: startingProject == project.name,
                    onTap: { await handleProjectTap(project) }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func loadProjects() async {
        isLoading = true
        error = nil
        
        let client = GatewayClient(baseURL: gatewayURL, apiKey: apiKey)
        
        do {
            projects = try await client.listProjects()
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func handleProjectTap(_ project: GatewayProject) async {
        if project.isRunning {
            onSelectProject(project)
            return
        }
        
        startingProject = project.name
        let client = GatewayClient(baseURL: gatewayURL, apiKey: apiKey)
        
        do {
            _ = try await client.startProject(project.name)
            let updated = try await client.projectStatus(project.name)
            
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = updated
            }
            
            startingProject = nil
            onSelectProject(updated)
        } catch {
            startingProject = nil
            self.error = error.localizedDescription
        }
    }
}

struct ProjectRow: View {
    let project: GatewayProject
    let isStarting: Bool
    let onTap: () async -> Void
    
    var body: some View {
        Button(action: { Task { await onTap() } }) {
            HStack(spacing: VibeTheme.Spacing.sm) {
                projectIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(VibeTheme.Typography.bodySemibold)
                        .foregroundStyle(VibeTheme.Colors.fg)
                    
                    HStack(spacing: VibeTheme.Spacing.xs) {
                        if project.hasGit {
                            Label("Git", systemImage: "arrow.triangle.branch")
                                .font(VibeTheme.Typography.caption2)
                                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                        }
                        
                        if project.hasPackageJson {
                            Label("Node", systemImage: "shippingbox")
                                .font(VibeTheme.Typography.caption2)
                                .foregroundStyle(VibeTheme.Colors.fgSecondary)
                        }
                    }
                }
                
                Spacer()
                
                if isStarting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    statusBadge
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VibeTheme.Colors.fgTertiary)
            }
            .padding(.vertical, VibeTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .disabled(isStarting)
    }
    
    private var projectIcon: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: 24))
            .foregroundStyle(VibeTheme.Colors.tint)
            .frame(width: 40, height: 40)
            .background(VibeTheme.Colors.tintSubtle)
            .cornerRadius(VibeTheme.Radius.sm)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if project.isRunning {
            HStack(spacing: 4) {
                Circle()
                    .fill(VibeTheme.Colors.Fallback.success)
                    .frame(width: 6, height: 6)
                
                Text("Running")
                    .font(VibeTheme.Typography.caption2)
                    .foregroundStyle(VibeTheme.Colors.Fallback.success)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VibeTheme.Colors.Fallback.success.opacity(0.15))
            .cornerRadius(VibeTheme.Radius.sm)
        } else {
            Text("Start")
                .font(VibeTheme.Typography.caption2)
                .foregroundStyle(VibeTheme.Colors.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VibeTheme.Colors.tintSubtle)
                .cornerRadius(VibeTheme.Radius.sm)
        }
    }
}

#Preview {
    NavigationStack {
        ProjectsView(
            gatewayURL: URL(string: "https://vibecode.helmes.me")!,
            apiKey: "test-key",
            onSelectProject: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
