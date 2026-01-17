import SwiftUI

struct SidebarSessionRowView: View {
    let session: AgentSession
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    
    private var isFavorited: Bool {
        session.isFavorite || session.isMasterFavorite
    }
    
    private var nameColor: Color {
        if session.isMasterFavorite {
            return Color(hex: 0xFAB283)
        } else if session.isFavorite {
            return Color(hex: 0xFAB283)
        }
        return Color(hex: 0xEEEEEE)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(session.name)
                    .font(.system(size: 15))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                
                Spacer()
                
                Text(shortenedPath)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0x808080))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: 0x1E1E1E) : Color.clear)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onToggleFavorite) {
                Label(
                    isFavorited ? "Unfavorite" : "Favorite",
                    systemImage: isFavorited ? "star.slash" : "star.fill"
                )
            }
            .tint(Color(hex: 0xFAB283))
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color(hex: 0x5C9CF5))
        }
    }
    
    private var shortenedPath: String {
        let path = session.projectPath
        if path.hasPrefix("/home/") {
            let components = path.dropFirst(6).split(separator: "/", maxSplits: 1)
            if components.count > 1 {
                return "~/\(components[1])"
            }
        }
        if let lastComponent = path.split(separator: "/").last {
            return "~/\(lastComponent)"
        }
        return path
    }
}


