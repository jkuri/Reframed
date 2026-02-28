import SwiftUI

struct SectionHeader: View {
  var icon: String? = nil
  let title: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    if let icon {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.secondaryText)
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
      }
    } else {
      Text(title)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ReframedColors.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
  }
}
