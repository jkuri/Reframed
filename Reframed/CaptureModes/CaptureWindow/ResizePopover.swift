import SwiftUI

struct ResizePopover: View {
  let windowController: WindowController
  let window: WindowInfo

  private let popoverBg = Color.hex("#000000")
  private let borderColor = Color.white.opacity(0.18)
  private let dividerColor = Color.white.opacity(0.22)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      resizeSectionHeader("Common")

      ResizePopoverRow(label: "1280 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 1280, height: 720)) }
      ResizePopoverRow(label: "1920 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1920, height: 1080)) }
      ResizePopoverRow(label: "2560 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 2560, height: 1440)) }

      Divider().background(dividerColor).padding(.vertical, 4)

      resizeSectionHeader("4:3")

      ResizePopoverRow(label: "640 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 640, height: 480)) }
      ResizePopoverRow(label: "800 \u{00d7} 600") { windowController.resize(window, to: CGSize(width: 800, height: 600)) }
      ResizePopoverRow(label: "1024 \u{00d7} 768") { windowController.resize(window, to: CGSize(width: 1024, height: 768)) }
      ResizePopoverRow(label: "1280 \u{00d7} 960") { windowController.resize(window, to: CGSize(width: 1280, height: 960)) }
      ResizePopoverRow(label: "1600 \u{00d7} 1200") { windowController.resize(window, to: CGSize(width: 1600, height: 1200)) }

      Divider().background(dividerColor).padding(.vertical, 4)

      resizeSectionHeader("16:9")

      ResizePopoverRow(label: "854 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 854, height: 480)) }
      ResizePopoverRow(label: "1280 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 1280, height: 720)) }
      ResizePopoverRow(label: "1920 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1920, height: 1080)) }
      ResizePopoverRow(label: "2560 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 2560, height: 1440)) }
      ResizePopoverRow(label: "3840 \u{00d7} 2160") { windowController.resize(window, to: CGSize(width: 3840, height: 2160)) }

      Divider().background(dividerColor).padding(.vertical, 4)

      resizeSectionHeader("16:10")

      ResizePopoverRow(label: "640 \u{00d7} 400") { windowController.resize(window, to: CGSize(width: 640, height: 400)) }
      ResizePopoverRow(label: "1280 \u{00d7} 800") { windowController.resize(window, to: CGSize(width: 1280, height: 800)) }
      ResizePopoverRow(label: "1440 \u{00d7} 900") { windowController.resize(window, to: CGSize(width: 1440, height: 900)) }
      ResizePopoverRow(label: "1680 \u{00d7} 1050") { windowController.resize(window, to: CGSize(width: 1680, height: 1050)) }
      ResizePopoverRow(label: "1920 \u{00d7} 1200") { windowController.resize(window, to: CGSize(width: 1920, height: 1200)) }
      ResizePopoverRow(label: "2560 \u{00d7} 1600") { windowController.resize(window, to: CGSize(width: 2560, height: 1600)) }

      Divider().background(dividerColor).padding(.vertical, 4)

      resizeSectionHeader("9:16")

      ResizePopoverRow(label: "360 \u{00d7} 640") { windowController.resize(window, to: CGSize(width: 360, height: 640)) }
      ResizePopoverRow(label: "720 \u{00d7} 1280") { windowController.resize(window, to: CGSize(width: 720, height: 1280)) }
      ResizePopoverRow(label: "1080 \u{00d7} 1920") { windowController.resize(window, to: CGSize(width: 1080, height: 1920)) }

      Divider().background(dividerColor).padding(.vertical, 4)

      resizeSectionHeader("Square")

      ResizePopoverRow(label: "480 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 480, height: 480)) }
      ResizePopoverRow(label: "640 \u{00d7} 640") { windowController.resize(window, to: CGSize(width: 640, height: 640)) }
      ResizePopoverRow(label: "720 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 720, height: 720)) }
      ResizePopoverRow(label: "1080 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1080, height: 1080)) }
      ResizePopoverRow(label: "1440 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 1440, height: 1440)) }
    }
    .padding(.vertical, 8)
    .frame(width: 200)
    .background(popoverBg)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.lg)
        .strokeBorder(borderColor, lineWidth: 0.5)
    )
    .presentationBackground(popoverBg)
  }

  private func resizeSectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: FontSize.xs, weight: .medium))
      .foregroundStyle(Color.white.opacity(0.6))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .padding(.bottom, 4)
  }
}

private struct ResizePopoverRow: View {
  let label: String
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.system(size: FontSize.xs))
        Spacer()
      }
      .foregroundStyle(Color.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: Radius.sm)
        .fill(isHovered ? Color.white.opacity(0.2) : Color.clear)
        .padding(.horizontal, 4)
    )
    .onHover { isHovered = $0 }
  }
}
