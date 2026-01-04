import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct InputAccessoryToolbar: View {
    let onKey: (SpecialKey) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(SpecialKey.allCases, id: \.self) { key in
                Button(action: { onKey(key) }) {
                    Text(key.label)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .frame(minWidth: 44, minHeight: 36)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

enum SpecialKey: CaseIterable {
    case escape
    case tab
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case ctrlC
    
    var label: String {
        switch self {
        case .escape: return "ESC"
        case .tab: return "TAB"
        case .arrowUp: return "↑"
        case .arrowDown: return "↓"
        case .arrowLeft: return "←"
        case .arrowRight: return "→"
        case .ctrlC: return "^C"
        }
    }
    
    var data: Data {
        switch self {
        case .escape: return Data([0x1B])
        case .tab: return Data([0x09])
        case .arrowUp: return Data([0x1B, 0x5B, 0x41])
        case .arrowDown: return Data([0x1B, 0x5B, 0x42])
        case .arrowRight: return Data([0x1B, 0x5B, 0x43])
        case .arrowLeft: return Data([0x1B, 0x5B, 0x44])
        case .ctrlC: return Data([0x03])
        }
    }
}
