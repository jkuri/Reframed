import SwiftUI

struct PermissionsView: View {
  var onAllGranted: () -> Void

  @State private var screenRecordingGranted = Permissions.hasScreenRecordingPermission
  @State private var accessibilityGranted = Permissions.hasAccessibilityPermission

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 32) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 128, height: 128)
        .padding(.top, -100)

      VStack(alignment: .leading, spacing: 32) {
        PermissionRow(
          title: "Screen Recording Permission",
          description: "Reframed needs to capture video of your screen. You might need to restart the app after granting it.",
          granted: screenRecordingGranted,
          grantedLabel: "Screen Recording enabled",
          requestLabel: "Allow Screen Recording"
        ) {
          Permissions.requestScreenRecordingPermission()
        }

        PermissionRow(
          title: "Accessibility Permission",
          description: "Reframed needs to capture mouse movements and shortcut keystrokes while you are recording your screen.",
          granted: accessibilityGranted,
          grantedLabel: "Accessibility access enabled",
          requestLabel: "Allow Accessibility Access"
        ) {
          Permissions.requestAccessibilityPermission()
        }
      }
    }
    .padding(80)
    .frame(minWidth: 800, minHeight: 500)
    .onReceive(timer) { _ in
      screenRecordingGranted = Permissions.hasScreenRecordingPermission
      accessibilityGranted = Permissions.hasAccessibilityPermission
      if screenRecordingGranted && accessibilityGranted {
        onAllGranted()
      }
    }
  }
}

private struct PermissionRow: View {
  let title: String
  let description: String
  let granted: Bool
  let grantedLabel: String
  let requestLabel: String
  let onRequest: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: FontSize.xs, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)

        Text(description)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: 250, alignment: .leading)

      Spacer()

      Button(action: {
        if !granted {
          onRequest()
        }
      }) {
        HStack(spacing: 6) {
          if granted {
            Image(systemName: "checkmark")
              .font(.system(size: FontSize.xs, weight: .semibold))
          }
          Text(granted ? grantedLabel : requestLabel)
            .font(.system(size: FontSize.xs, weight: .medium))
        }
        .frame(width: 260)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: Radius.lg)
            .stroke(granted ? Color.green.opacity(0.5) : ReframedColors.permissionBorder, lineWidth: 1)
        )
        .foregroundStyle(granted ? .green : ReframedColors.permissionText)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal)
  }
}
