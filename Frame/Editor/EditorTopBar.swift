import SwiftUI

struct EditorTopBar: View {
  @Bindable var editorState: EditorState
  let onOpenFolder: () -> Void
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        Button(action: onOpenFolder) {
          Image(systemName: "folder")
            .font(.system(size: 13))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrameColors.primaryText)

        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.system(size: 13))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrameColors.primaryText)
      }

      Spacer()

      HStack(spacing: 8) {
        Text(editorState.projectName)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(FrameColors.primaryText)

        if editorState.isExporting {
          HStack(spacing: 6) {
            ProgressView(value: editorState.exportProgress)
              .frame(width: 120)
            Text("\(Int(editorState.exportProgress * 100))%")
              .font(.system(size: 11).monospacedDigit())
              .foregroundStyle(FrameColors.secondaryText)
          }
        }
      }

      Spacer()

      Button(action: { editorState.showExportSheet = true }) {
        Text("Export")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white)
          .padding(.horizontal, 16)
          .frame(height: 28)
          .background(Color.blue)
          .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .disabled(editorState.isExporting)
      .opacity(editorState.isExporting ? 0.4 : 1.0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }
}
