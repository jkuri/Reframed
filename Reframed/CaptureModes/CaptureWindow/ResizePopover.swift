import SwiftUI

struct ResizePopover: View {
  let windowController: WindowController
  let window: WindowInfo

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "Common")

      ResizeRow(label: "1280 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 1280, height: 720)) }
      ResizeRow(label: "1920 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1920, height: 1080)) }
      ResizeRow(label: "2560 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 2560, height: 1440)) }

      Divider().background(ReframedColors.divider).padding(.vertical, 4)

      SectionHeader(title: "4:3")

      ResizeRow(label: "640 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 640, height: 480)) }
      ResizeRow(label: "800 \u{00d7} 600") { windowController.resize(window, to: CGSize(width: 800, height: 600)) }
      ResizeRow(label: "1024 \u{00d7} 768") { windowController.resize(window, to: CGSize(width: 1024, height: 768)) }
      ResizeRow(label: "1280 \u{00d7} 960") { windowController.resize(window, to: CGSize(width: 1280, height: 960)) }
      ResizeRow(label: "1600 \u{00d7} 1200") { windowController.resize(window, to: CGSize(width: 1600, height: 1200)) }

      Divider().background(ReframedColors.divider).padding(.vertical, 4)

      SectionHeader(title: "16:9")

      ResizeRow(label: "854 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 854, height: 480)) }
      ResizeRow(label: "1280 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 1280, height: 720)) }
      ResizeRow(label: "1920 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1920, height: 1080)) }
      ResizeRow(label: "2560 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 2560, height: 1440)) }
      ResizeRow(label: "3840 \u{00d7} 2160") { windowController.resize(window, to: CGSize(width: 3840, height: 2160)) }

      Divider().background(ReframedColors.divider).padding(.vertical, 4)

      SectionHeader(title: "16:10")

      ResizeRow(label: "640 \u{00d7} 400") { windowController.resize(window, to: CGSize(width: 640, height: 400)) }
      ResizeRow(label: "1280 \u{00d7} 800") { windowController.resize(window, to: CGSize(width: 1280, height: 800)) }
      ResizeRow(label: "1440 \u{00d7} 900") { windowController.resize(window, to: CGSize(width: 1440, height: 900)) }
      ResizeRow(label: "1680 \u{00d7} 1050") { windowController.resize(window, to: CGSize(width: 1680, height: 1050)) }
      ResizeRow(label: "1920 \u{00d7} 1200") { windowController.resize(window, to: CGSize(width: 1920, height: 1200)) }
      ResizeRow(label: "2560 \u{00d7} 1600") { windowController.resize(window, to: CGSize(width: 2560, height: 1600)) }

      Divider().background(ReframedColors.divider).padding(.vertical, 4)

      SectionHeader(title: "9:16")

      ResizeRow(label: "360 \u{00d7} 640") { windowController.resize(window, to: CGSize(width: 360, height: 640)) }
      ResizeRow(label: "720 \u{00d7} 1280") { windowController.resize(window, to: CGSize(width: 720, height: 1280)) }
      ResizeRow(label: "1080 \u{00d7} 1920") { windowController.resize(window, to: CGSize(width: 1080, height: 1920)) }

      Divider().background(ReframedColors.divider).padding(.vertical, 4)

      SectionHeader(title: "Square")

      ResizeRow(label: "480 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 480, height: 480)) }
      ResizeRow(label: "640 \u{00d7} 640") { windowController.resize(window, to: CGSize(width: 640, height: 640)) }
      ResizeRow(label: "720 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 720, height: 720)) }
      ResizeRow(label: "1080 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1080, height: 1080)) }
      ResizeRow(label: "1440 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 1440, height: 1440)) }
    }
    .padding(.vertical, 8)
    .frame(width: 200)
    .popoverContainerStyle()
  }
}

private struct ResizeRow: View {
  let label: String
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.system(size: 13))
        Spacer()
      }
      .foregroundStyle(ReframedColors.primaryText)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: Radius.sm)
        .fill(isHovered ? ReframedColors.hoverBackground : Color.clear)
        .padding(.horizontal, 4)
    )
    .onHover { isHovered = $0 }
  }
}
