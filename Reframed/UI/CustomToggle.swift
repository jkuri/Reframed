import SwiftUI

struct CustomToggle: View {
  @Binding var isOn: Bool
  @Environment(\.colorScheme) private var colorScheme

  private var trackColor: Color {
    if isOn {
      return ReframedColors.primary
    }
    return colorScheme == .dark
      ? Color.white.opacity(0.15)
      : Color.black.opacity(0.12)
  }

  private var thumbColor: Color {
    if isOn {
      return ReframedColors.primaryForeground
    }
    return colorScheme == .dark ? .white : .white
  }

  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      Capsule()
        .fill(trackColor)
        .frame(width: 34, height: 20)
        .overlay(alignment: isOn ? .trailing : .leading) {
          Circle()
            .fill(thumbColor)
            .frame(width: 16, height: 16)
            .padding(2)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
        }
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
    .buttonStyle(.plain)
  }
}
