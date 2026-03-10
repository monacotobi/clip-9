import SwiftUI

// MARK: - Colors

private extension Color {
    static let clippyBg     = Color(red: 0.039, green: 0.059, blue: 0.039) // #0A0F0A
    static let clippyAccent = Color(red: 0.0,   green: 1.0,   blue: 0.533) // #00FF88
    static let clippyDim    = Color(red: 0.533, green: 0.533, blue: 0.533) // #888
    static let clippyBorder = Color(red: 0.15,  green: 0.22,  blue: 0.15)
}

// MARK: - PickerView

struct PickerView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var state: PickerState
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("◈  CLIPBOARD")
                    .font(.custom("SF Mono", size: 11).weight(.semibold))
                    .foregroundColor(.clippyAccent)
                    .tracking(2)
                Spacer()
                Text("\(monitor.history.count) item\(monitor.history.count == 1 ? "" : "s")")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.clippyDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Color.clippyBorder)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(monitor.history.enumerated()), id: \.offset) { index, text in
                        RowView(index: index, text: text, isSelected: state.selectedIndex == index)
                            .onTapGesture {
                                state.selectedIndex = index
                                onSelect(text)
                            }
                    }
                }
            }
        }
        .background(Color.clippyBg)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.clippyBorder, lineWidth: 1)
        )
        .onReceive(monitor.$history) { _ in
            state.selectedIndex = 0
        }
    }
}

// MARK: - Row

private struct RowView: View {
    let index: Int
    let text: String
    let isSelected: Bool

    private var label: String { index < 9 ? "\(index + 1)" : "0" }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isSelected ? Color.clippyAccent : Color.clear)
                .frame(width: 3)

            HStack(spacing: 10) {
                Text(label)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(isSelected ? .clippyAccent : .clippyDim)
                    .frame(width: 14, alignment: .trailing)

                Text(isSelected ? "▶" : " ")
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(.clippyAccent)
                    .frame(width: 14)

                Text(text)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(isSelected ? .white : .clippyDim)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 44)
        .background(isSelected ? Color.clippyAccent.opacity(0.07) : Color.clear)
        .animation(.easeInOut(duration: 0.08), value: isSelected)
    }
}
