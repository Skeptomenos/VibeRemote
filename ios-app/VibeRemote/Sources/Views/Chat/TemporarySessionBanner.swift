import SwiftUI

struct TemporarySessionBanner: View {
    let onSave: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: 0x808080))
            
            Text("Temporary Session")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: 0x808080))
            
            Spacer()
            
            Button(action: onSave) {
                Text("Save")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0xFAB283))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: 0x1E1E1E))
    }
}



#Preview {
    VStack(spacing: 0) {
        TemporarySessionBanner(onSave: {})
        Spacer()
    }
    .background(Color(hex: 0x0A0A0A))
    .preferredColorScheme(.dark)
}
