import SwiftUI

struct SectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(FrameColors.dimLabel)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .padding(.bottom, 4)
  }
}
