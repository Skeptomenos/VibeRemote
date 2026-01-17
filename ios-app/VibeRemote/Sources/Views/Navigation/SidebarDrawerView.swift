import SwiftUI

struct SidebarDrawerView<Sidebar: View, Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @GestureState private var dragOffset: CGFloat = 0
    @State private var sidebarWidth: CGFloat = 280
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    private var effectiveSidebarWidth: CGFloat {
        isCompact ? 280 : 320
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                contentLayer(geometry: geometry)
                sidebarLayer(geometry: geometry)
                
                if isCompact && isOpen {
                    dimmingOverlay
                }
            }
            .gesture(edgeSwipeGesture(geometry: geometry))
            .onAppear {
                sidebarWidth = effectiveSidebarWidth
            }
            .onChange(of: horizontalSizeClass) { _, _ in
                sidebarWidth = effectiveSidebarWidth
            }
        }
    }
    
    // MARK: - Content Layer
    
    @ViewBuilder
    private func contentLayer(geometry: GeometryProxy) -> some View {
        let offset = contentOffset(geometry: geometry)
        let width = contentWidth(geometry: geometry)
        
        content()
            .frame(width: width)
            .offset(x: offset)
            .animation(.easeOut(duration: 0.2), value: isOpen)
            .animation(.easeOut(duration: 0.2), value: dragOffset)
    }
    
    private func contentOffset(geometry: GeometryProxy) -> CGFloat {
        if isCompact {
            let baseOffset = isOpen ? sidebarWidth : 0
            let dragContribution = max(0, dragOffset)
            return baseOffset + dragContribution
        } else {
            return isOpen ? sidebarWidth : 0
        }
    }
    
    private func contentWidth(geometry: GeometryProxy) -> CGFloat {
        if isCompact {
            return geometry.size.width
        } else {
            return isOpen ? geometry.size.width - sidebarWidth : geometry.size.width
        }
    }
    
    // MARK: - Sidebar Layer
    
    @ViewBuilder
    private func sidebarLayer(geometry: GeometryProxy) -> some View {
        let offset = sidebarOffset()
        
        sidebar()
            .frame(width: sidebarWidth)
            .background(Color(hex: 0x141414))
            .offset(x: offset)
            .animation(.easeOut(duration: 0.2), value: isOpen)
            .animation(.easeOut(duration: 0.2), value: dragOffset)
    }
    
    private func sidebarOffset() -> CGFloat {
        let baseOffset = isOpen ? 0 : -sidebarWidth
        let dragContribution = isOpen ? 0 : max(0, dragOffset)
        return baseOffset + dragContribution
    }
    
    // MARK: - Dimming Overlay
    
    private var dimmingOverlay: some View {
        Color.black
            .opacity(0.3)
            .ignoresSafeArea()
            .offset(x: sidebarWidth)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) {
                    isOpen = false
                }
            }
    }
    
    // MARK: - Gesture Handling
    
    private func edgeSwipeGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                let isEdgeSwipe = value.startLocation.x < 20
                let isClosingSwipe = isOpen && value.translation.width < 0
                
                if !isOpen && isEdgeSwipe {
                    state = value.translation.width
                } else if isClosingSwipe {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                handleDragEnd(value: value)
            }
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold = sidebarWidth / 2
        let velocity = value.velocity.width
        
        if !isOpen {
            guard value.startLocation.x < 20 else { return }
            let shouldOpen = value.translation.width > threshold || velocity > 500
            withAnimation(.easeOut(duration: 0.15)) {
                isOpen = shouldOpen
            }
        } else {
            let shouldClose = value.translation.width < -threshold || velocity < -500
            withAnimation(.easeOut(duration: 0.15)) {
                isOpen = !shouldClose
            }
        }
    }
}



// MARK: - Preview

#Preview("iPhone - Closed") {
    SidebarDrawerPreview(isOpen: false)
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPhone - Open") {
    SidebarDrawerPreview(isOpen: true)
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad - Open") {
    SidebarDrawerPreview(isOpen: true)
        .environment(\.horizontalSizeClass, .regular)
}

private struct SidebarDrawerPreview: View {
    @State var isOpen: Bool
    
    var body: some View {
        SidebarDrawerView(isOpen: $isOpen) {
            VStack {
                Text("Sidebar")
                    .font(.title)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding()
        } content: {
            ZStack {
                Color(hex: 0x0A0A0A)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: { isOpen.toggle() }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Spacer()
                    
                    Text("Main Content")
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
