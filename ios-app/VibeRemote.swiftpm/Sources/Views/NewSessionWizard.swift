import SwiftUI

struct NewSessionWizard: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var sessionName = ""
    @State private var projectPath = "~/Repos/"
    @State private var selectedAgent: AgentType = .opencode
    
    let onCreate: (AgentSession) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    TextField("Session Name", text: $sessionName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Project Path", text: $projectPath)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }
                
                Section("Agent Type") {
                    Picker("Agent", selection: $selectedAgent) {
                        ForEach(AgentType.allCases, id: \.self) { agent in
                            Label(agent.displayName, systemImage: agent.iconName)
                                .tag(agent)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                Section {
                    Button(action: createSession) {
                        HStack {
                            Spacer()
                            Label("Launch Session", systemImage: "play.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var isValid: Bool {
        !sessionName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !projectPath.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func createSession() {
        let session = AgentSession(
            name: sessionName.trimmingCharacters(in: .whitespaces),
            projectPath: projectPath.trimmingCharacters(in: .whitespaces),
            agentType: selectedAgent
        )
        onCreate(session)
        dismiss()
    }
}
