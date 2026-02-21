import SwiftUI

struct ToggleRow: View {
  let label: String
  @Binding var isOn: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack {
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(ReframedColors.primaryText)
      Spacer()
      CustomToggle(isOn: $isOn)
    }
  }
}
